// ADR 0002 §1: lib/ 아래 폴더가 import해도 되는 것을 검사한다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 폴더나 파일 → (import해도 되는 다른 앱 폴더·파일, 금지 패키지 접두). ADR 0002 표의 줄을 여기에 더한다.
const rules = <String, (List<String>, List<String>)>{
  'content': ([], ['package:flutter', 'package:supabase', 'dart:ui']),
  'engine': (['content'], ['package:flutter', 'package:supabase', 'dart:ui']),
  'sync': (['engine'], ['package:flutter', 'dart:ui']), // ADR 0005 §3: supabase_flutter는 허용
  'fake': (['backend.dart'], _screenBanned),
  'screens': (['backend.dart'], _screenBanned),
  // backend.dart는 표에 없지만 3절 코드가 main.dart에서 전역 backend에 넣는다.
  'main.dart': (['backend.dart', 'screens', 'fake', 'live', 'firebase_options.dart'], ['package:supabase', 'package:google_sign_in', 'package:firebase_analytics']),
};
const _screenBanned = ['package:supabase', 'package:google_sign_in', 'package:firebase_'];

/// 아직 없어도 되는 폴더(팀원이 만든다).
const optional = {'screens'};

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

void main() {
  final lib = Directory('lib').absolute.uri;

  for (final MapEntry(key: folder, value: (allowed, banned)) in rules.entries) {
    final missing = optional.contains(folder) && !Directory('lib/$folder').existsSync();
    test('lib/$folder는 허용된 것만 import한다', skip: missing ? 'lib/$folder/가 아직 없다' : null, () {
      final files = folder.endsWith('.dart')
          ? [File('lib/$folder')]
          : Directory('lib/$folder')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList();
      expect(files, isNotEmpty, reason: 'lib/$folder에 파일이 없다');

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

  test('lib/backend.dart는 flutter/foundation.dart만 import한다', () {
    final imports = _import.allMatches(File('lib/backend.dart').readAsStringSync()).map((m) => m[1]);
    expect(imports, ['package:flutter/foundation.dart']);
  });
}
