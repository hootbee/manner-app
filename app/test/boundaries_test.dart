// ADR 0002 §1: lib/ 아래 폴더가 import해도 되는 것을 검사한다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 폴더 → (import해도 되는 다른 앱 폴더, 금지 패키지 접두). ADR 0002 표의 줄을 여기에 더한다.
const rules = <String, (List<String>, List<String>)>{
  'content': ([], ['package:flutter', 'package:supabase', 'dart:ui']),
};

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

void main() {
  final lib = Directory('lib').absolute.uri;

  for (final MapEntry(key: folder, value: (allowed, banned)) in rules.entries) {
    test('lib/$folder/는 허용된 것만 import한다', () {
      final files = Directory('lib/$folder')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty, reason: 'lib/$folder/에 파일이 없다');

      final violations = <String>[];
      for (final file in files) {
        for (final m in _import.allMatches(file.readAsStringSync())) {
          final target = m[1]!;
          if (banned.any(target.startsWith)) {
            violations.add('${file.path}: $target');
            continue;
          }
          final String path;
          if (target.startsWith('package:mannerfit/')) {
            path = target.substring('package:mannerfit/'.length);
          } else if (!target.contains(':')) {
            final resolved = file.absolute.uri.resolve(target).toString();
            path = resolved.startsWith('$lib') ? resolved.substring('$lib'.length) : resolved;
          } else {
            continue; // dart: 와 외부 패키지
          }
          final top = path.split('/').first;
          if (top != folder && !allowed.contains(top)) violations.add('${file.path}: $target');
        }
      }
      expect(violations, isEmpty);
    });
  }
}
