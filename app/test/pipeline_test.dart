import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/templates.dart';

import '../tool/pipeline.dart';

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

  _a6(enumOf);
}

// ---- 작업 A6: tool/pipeline.dart 순수 함수 (ADR 0009 §2, §3, §4, §9, §11) ----

Iterable<String> _keysOf(Object? v) sync* {
  if (v is Map) {
    for (final e in v.entries) {
      yield e.key as String;
      yield* _keysOf(e.value);
    }
  } else if (v is List) {
    for (final x in v) {
      yield* _keysOf(x);
    }
  }
}

// 프롬프트·pipeline.dart 검사 (ADR 0009 §4): 이름 → 걸린 금지 값. 단어 경계로 맞춘다.
// 부분 문자열로 맞추면 border·box·proxy 같은 흔한 영단어가 걸린다.
List<String> forbiddenHits(Map<String, String> texts, Iterable<String> words) => [
      for (final t in texts.entries)
        for (final w in words)
          if (RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false).hasMatch(t.value)) '${t.key}: $w',
    ];

// 디렉터리와 하위 폴더의 .md 파일 (프롬프트 검사 대상).
List<File> promptFiles(Directory dir) =>
    dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.md')).toList();

void _a6(Set<Object?> Function(String) enumOf) {
  final text = File('assets/content.json').readAsStringSync();
  final content = parseContent(text);
  final raw = jsonDecode(text) as Map<String, Object?>;

  group('blind', () {
    test('A-umbrella-01: 답이 담긴 키가 어디에도 없고 보기 문장 집합은 같다', () {
      final q = content.questions['A-umbrella-01']!;
      final before = jsonEncode(q);
      expect(_keysOf(q), containsAll(['grade', 'feedback'])); // 전제: 원본에는 있다
      final b = blind(q, Random(1));
      expect(_keysOf(b), isNot(contains('grade')));
      expect(_keysOf(b), isNot(contains('feedback')));
      expect(_keysOf(b).toSet().intersection(blindHidden), isEmpty);
      Set<Object?> texts(Json x) => {for (final o in x['options']! as List) (o as Map)['text']};
      expect(texts(b), texts(q));
      expect((b['options']! as List), hasLength(4));
      expect(jsonEncode(q), before, reason: '원본은 바뀌지 않는다');
    });

    test('options 순서는 섞인다', () {
      final q = content.questions['A-umbrella-01']!;
      List<Object?> order(Json x) => [for (final o in x['options']! as List) (o as Map)['text']];
      final orders = {for (var seed = 0; seed < 10; seed++) order(blind(q, Random(seed))).join('|')};
      expect(orders.length, greaterThan(1));
    });

    test('형식 이름 없이 상수만 본다: 깊이 상관없이 지우고 blindShuffled 배열을 섞는다', () {
      final doc = <String, Object?>{
        'id': 'x',
        'deep': {
          'list': [
            {'answer': 1, 'keep': 'k'},
          ],
        },
        'cards': List<Object?>.generate(20, (i) => {'n': i, 'note': 'n$i'}),
      };
      final b = blind(doc, Random(3));
      expect(_keysOf(b).toSet(), {'id', 'deep', 'list', 'keep', 'cards', 'n'});
      final ns = [for (final c in b['cards']! as List) (c as Map)['n']];
      expect(ns.toSet(), {for (var i = 0; i < 20; i++) i});
      expect(ns, isNot(List<int>.generate(20, (i) => i)));
    });
  });

  group('addScenarios', () {
    final scenario = <String, Object?>{
      'id': 'B-test-01',
      'manner': 2,
      'prompt': '테스트 문제',
      'feedback': {'title': '제목', 'why': '이유'},
    };
    String indented(Object? v) =>
        const JsonEncoder.withIndent('  ').convert(v).split('\n').map((l) => '    $l').join('\n');
    const scenariosEnd = '    }\n  ],\n  "days"';
    const mannersEnd = '    }\n  ],\n  "scenarios"';

    test('전제: 지금 파일은 withIndent("  ") + 줄바꿈 하나와 같다', () {
      expect('${const JsonEncoder.withIndent('  ').convert(raw)}\n', text);
      expect(scenariosEnd.allMatches(text), hasLength(1));
      expect(mannersEnd.allMatches(text), hasLength(1));
    });

    test('시나리오 하나를 붙이면 붙인 줄과 version 줄만 다르다(바이트)', () {
      final out = addScenarios(text, [scenario]);
      final expected = text
          .replaceFirst('"version": ${content.version}', '"version": ${content.version + 1}')
          .replaceFirst(scenariosEnd, '    },\n${indented(scenario)}\n  ],\n  "days"');
      expect(out, expected);
      expect(out.endsWith('}\n'), isTrue);
      expect(out.endsWith('\n\n'), isFalse);
    });

    test('매너 99가 manners에 없으면 매너 항목도 붙는다', () {
      final m = <String, Object?>{'id': 99, 'name': '새 매너', 'principle': 'A', 'places': ['거리']};
      final out = addScenarios(text, [scenario], manner: m);
      final expected = text
          .replaceFirst('"version": ${content.version}', '"version": ${content.version + 1}')
          .replaceFirst(mannersEnd, '    },\n${indented(m)}\n  ],\n  "scenarios"')
          .replaceFirst(scenariosEnd, '    },\n${indented(scenario)}\n  ],\n  "days"');
      expect(out, expected);
    });

    test('매너가 이미 있으면 붙이지 않는다', () {
      final m = <String, Object?>{'id': 2, 'name': '다른 이름', 'principle': 'A', 'places': ['거리']};
      expect(addScenarios(text, [scenario], manner: m), addScenarios(text, [scenario]));
      expect(addScenarios(text, [scenario], manner: m), isNot(contains('다른 이름')));
    });

    test('기존 항목과 days는 그대로다', () {
      final out = jsonDecode(addScenarios(text, [scenario, {...scenario, 'id': 'B-test-02'}])) as Map;
      final before = raw['scenarios']! as List;
      final after = out['scenarios'] as List;
      expect(after, hasLength(before.length + 2));
      expect(after.take(before.length).toList(), before);
      expect(out['days'], raw['days']);
      expect(out['manners'], raw['manners']);
      expect(out['version'], content.version + 1);
    });
  });

  group('openPipelinePr', () {
    Json pr(String ref) => {'number': 1, 'head': {'ref': ref}};
    test('content/ 로 시작하는 head가 있으면 참', () {
      expect(openPipelinePr([pr('feat/x'), pr('content/manner-2-1')]), isTrue);
    });
    test('없거나 다른 접두사면 거짓', () {
      expect(openPipelinePr([]), isFalse);
      expect(openPipelinePr([pr('feat/x'), pr('mycontent/manner-2-1'), pr('docs/content/a')]), isFalse);
    });
    test('head.ref가 없는 항목이면 거짓으로 넘기지 않고 예외', () {
      // gh의 --json headRefName 같은 다른 모양을 받으면 막는 검사가 조용히 꺼진다.
      expect(() => openPipelinePr([{'headRefName': 'content/manner-2-1'}]), throwsFormatException);
    });
  });

  group('prBody', () {
    String body({
      bool hasSources = true,
      List<Json> flags = const [],
      bool newManner = false,
      String note = '',
    }) =>
        prBody(
          hasSources: hasSources,
          manner: 4,
          mannerName: '식당 자리',
          scenarioCount: 3,
          questionCount: 5,
          fromVersion: 7,
          newManner: newManner,
          runUrl: 'https://example.test/run/1',
          flags: flags,
          questions: [
            {'id': 'B-door-01', 'prompt': '첫째 지문'},
            {'id': 'B-door-02', 'prompt': '둘째\n지문'},
          ],
          model: 'claude-opus-5-5',
          sha: 'abc1234',
          usage: '1/2/3/4',
          validate: '오류 0, 경고 1',
        );

    test('묶인 문서가 없으면 첫 줄이 "근거 문서 없음"이고 그 뒤 빈 줄', () {
      final b = body(hasSources: false);
      expect(b.split('\n').take(3).toList(), ['근거 문서 없음', '', '## 무엇을']);
    });

    test('묶인 문서가 있으면 그 줄이 없다', () {
      final b = body();
      expect(b.split('\n').first, '## 무엇을');
    });

    test('형식 표시는 표의 한 줄이 되고, 표시가 없으면 "없음"', () {
      final b = body(flags: [
        {'id': 'B-door-02', 'kind': '형식', 'note': '순서를 고르는 편이 맞다'},
      ]);
      expect(b, contains('| 문제 | 종류 | 메모 |\n| --- | --- | --- |\n| `B-door-02` | 형식 | 순서를 고르는 편이 맞다 |\n'));
      final none = body();
      expect(none, contains('## 검토 표시 (Claude. 막지 않는다)\n없음\n'));
      expect(none, isNot(contains('| 문제 |')));
    });

    test('메모의 | 와 줄바꿈이 표를 깨지 않는다', () {
      final b = body(flags: [
        {'id': 'B-door-01', 'kind': '정답', 'note': 'a|b\nc'},
      ]);
      expect(b, contains('| `B-door-01` | 정답 | a\\|b c |\n'));
    });

    test('본문 구성: 무엇을·왜·새 문제(prompt만)·확인·체크리스트', () {
      final b = body(newManner: true);
      expect(b, contains('매너 4 "식당 자리"에 기본 시나리오 3개(펼친 문제 5개)를 더한다. content version 7 → 8.'));
      expect(b, contains('매너 항목도 더한다'));
      expect(body(), isNot(contains('매너 항목도 더한다')));
      expect(b, contains('## 왜\nADR 0009 파이프라인 실행 https://example.test/run/1\n'));
      expect(b, contains('- `B-door-01`: 첫째 지문\n- `B-door-02`: 둘째 지문\n'));
      expect(b, contains('- 코드 검사: 오류 0, 경고 1\n'));
      expect(b, contains('- 모델 claude-opus-5-5 · 커밋 abc1234 · 호출별 토큰(입력/캐시 쓰기/캐시 읽기/출력) 1/2/3/4\n'));
      expect(b, contains('## 사람이 확인할 것\n- [ ] 새 문제를 모두 읽었다'));
      expect('- [ ] '.allMatches(b), hasLength(4));
    });
  });

  group('프롬프트 검사 (ADR 0009 §4)', () {
    final forbidden = {...enumOf('format'), ...enumOf('template')}.cast<String>();

    test('금지 값은 스키마에서 읽는다(비어 있지 않다)', () {
      expect(forbidden, containsAll(['choice', 'sidewalk']));
      expect(forbidden.length, greaterThanOrEqualTo(7));
    });

    test('금지 값이 든 문자열은 걸린다', () {
      for (final w in forbidden) {
        expect(forbiddenHits({'가짜': '이 상황은 $w 로 낸다'}, forbidden), ['가짜: $w']);
        expect(forbiddenHits({'가짜': '$w를 쓴다'}, forbidden), ['가짜: $w'], reason: '한글이 붙어도 걸린다');
      }
    });

    test('대문자가 섞여도 걸린다', () {
      expect(forbiddenHits({'가짜': 'Choice 로 낸다'}, forbidden), ['가짜: choice']);
      expect(forbiddenHits({'가짜': 'Sidewalk를 쓴다'}, forbidden), ['가짜: sidewalk']);
      expect(forbiddenHits({'가짜': 'POSITION'}, forbidden), ['가짜: position']);
    });

    test('하위 폴더의 .md도 검사 대상이다', () {
      final tmp = Directory.systemTemp.createTempSync('prompts');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory('${tmp.path}/sub/deeper').createSync(recursive: true);
      File('${tmp.path}/ok.md').writeAsStringSync('깨끗하다');
      File('${tmp.path}/sub/deeper/bad.md').writeAsStringSync('이 상황은 stairs 로 낸다');
      File('${tmp.path}/sub/note.txt').writeAsStringSync('stairs');
      final files = promptFiles(tmp);
      expect(files.map((f) => f.path.split('/').last).toSet(), {'ok.md', 'bad.md'});
      final hits = forbiddenHits({for (final f in files) f.path: f.readAsStringSync()}, forbidden);
      expect(hits, hasLength(1));
      expect(hits.single, endsWith('bad.md: stairs'));
    });

    test('깨끗한 문자열은 통과한다(흔한 영단어의 일부는 걸리지 않는다)', () {
      const clean = '스키마의 다른 형식이나 border box proxy ordered choices positions 도 괜찮다';
      expect(forbiddenHits({'깨끗': clean}, forbidden), isEmpty);
    });

    test('app/tool/pipeline.dart에는 금지 값이 없다', () {
      final src = File('tool/pipeline.dart').readAsStringSync();
      expect(src, isNotEmpty);
      expect(forbiddenHits({'tool/pipeline.dart': src}, forbidden), isEmpty);
    });

    final dir = Directory('../pipeline/prompts');
    test('pipeline/prompts/*.md에는 금지 값이 없다', () {
      final files = promptFiles(dir);
      expect(files, isNotEmpty, reason: '디렉터리가 있는데 .md가 없다');
      final texts = {for (final f in files) f.path: f.readAsStringSync()};
      expect(forbiddenHits(texts, forbidden), isEmpty);
    }, skip: dir.existsSync() ? false : 'skip: pipeline/prompts/ 가 아직 없다 (A8에서 만든다). 건너뛴 검사다');
  });
}
