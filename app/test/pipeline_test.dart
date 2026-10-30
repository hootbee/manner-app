import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/templates.dart';

// 파이프라인이 읽는 템플릿 정의 (ADR 0009 §4, 작업 A5).
void main() {
  final defs = (jsonDecode(File('assets/content.schema.json').readAsStringSync())
      as Map<String, Object?>)['definitions']! as Map<String, Object?>;
  final s = defs['scenario']! as Map<String, Object?>;
  final props = s['properties']! as Map<String, Object?>;
  Set<Object?> enumOf(String key) => {...((props[key]! as Map)['enum'] as List)};

  test('스키마 template enum과 templateSpots 키가 같다', () {
    expect(enumOf('template'), templateSpots.keys.toSet());
  });

  test('format enum마다 description이 있는 형식 분기가 있다', () {
    final branches = {
      for (final b in (s['allOf']! as List).cast<Map<String, Object?>>())
        ((((b['if'] as Map)['properties'] as Map)['format'] as Map)['const']): b['description'],
    };
    expect(enumOf('format'), isNotEmpty);
    for (final f in enumOf('format')) {
      expect(branches.containsKey(f), isTrue, reason: '형식 분기 없음: $f');
      expect(branches[f], isA<String>().having((d) => d.trim(), 'trim', isNotEmpty),
          reason: 'description 없음: $f');
    }
  });
}
