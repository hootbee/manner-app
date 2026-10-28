// ADR 0007 §6: 디버그 빌드만 Crashlytics 보고를 끈다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _name = 'firebase_crashlytics_collection_enabled';

/// `<application>` 안의 meta-data 태그들.
Iterable<String> _metaData(String manifest) {
  final app = RegExp(r'<application[\s\S]*?</application>').firstMatch(manifest)?[0] ?? '';
  return RegExp(r'<meta-data[^>]*>').allMatches(app).map((m) => m[0]!);
}

void main() {
  test('디버그 manifest는 Crashlytics 수집을 끈다', () {
    final tags = _metaData(File('android/app/src/debug/AndroidManifest.xml').readAsStringSync())
        .where((t) => t.contains('android:name="$_name"'));
    expect(tags, hasLength(1));
    expect(tags.single, contains('android:value="false"'));
  });

  test('main manifest에는 Crashlytics 수집 설정이 없다(릴리스·프로필은 보낸다)', () {
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), isNot(contains(_name)));
  });
}
