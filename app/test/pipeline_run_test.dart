import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/pipeline.dart';

// 파이프라인 1~5단계를 잇는 runPipeline (ADR 0009 §3). 네트워크는 MockClient, 코드 검사는 가짜, 파일은 임시 리포다.
const _files = [
  'pipeline/prompts/common.md',
  'pipeline/prompts/generate.md',
  'pipeline/prompts/blind.md',
  'pipeline/prompts/judge.md',
  'pipeline/sources/sources.json',
  'docs/concept.md',
  'app/assets/content.schema.json',
  'app/assets/content.json',
];

http.Response _reply(String text) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'content': [
          {'type': 'text', 'text': text},
        ],
        'stop_reason': 'end_turn',
        'usage': {'input_tokens': 10, 'cache_creation_input_tokens': 5, 'cache_read_input_tokens': 0, 'output_tokens': 7},
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late Directory root;
  late List<String> users; // 호출마다 사용자 메시지
  late String before;

  // 매너 2의 기존 시나리오를 id만 바꿔 새 시나리오로 돌려준다.
  final original = (jsonDecode(File('assets/content.json').readAsStringSync())['scenarios'] as List)
      .cast<Map<String, Object?>>()
      .firstWhere((s) => s['id'] == 'A-umbrella-01');
  final generated = {...original, 'id': 'A-umbrella-09'};

  MockClient mock({String judge = '[{"id": "A-umbrella-09", "kind": "형식", "note": "메모"}]'}) =>
      MockClient((r) async {
        final body = jsonDecode(r.body) as Map;
        users.add(((body['messages'] as List).single as Map)['content'] as String);
        return switch (users.length) {
          // 앞뒤 설명과 코드 블록 표시가 붙어도 읽는다(§8 "첫 { 부터 마지막 }까지").
          1 => _reply('여기 있다\n```json\n${jsonEncode({'manner': null, 'scenarios': [generated]})}\n```'),
          2 => _reply('[{"id": "A-umbrella-09", "picked": "블라인드답"}]'),
          _ => _reply(judge),
        };
      });

  Future<String> run(http.Client client, {List<Map<String, Object?>> open = const [], String Function()? check}) =>
      runPipeline(
        client: client,
        apiKey: 'test-key-dummy',
        manner: 2,
        openPulls: open,
        root: root.path,
        runUrl: 'https://example.test/run/1',
        sha: 'abc1234',
        random: Random(1),
        check: (content, previous) async {
          expect(File(previous).readAsStringSync(), before, reason: '이전 파일은 실행 전 content.json이다');
          expect(File(content).readAsStringSync(), contains('A-umbrella-09'));
          return check?.call() ?? 'app/assets/content.json valid';
        },
      );

  setUp(() {
    users = [];
    root = Directory.systemTemp.createTempSync('pipeline');
    for (final f in _files) {
      File('${root.path}/$f')
        ..createSync(recursive: true)
        ..writeAsBytesSync(File('../$f').readAsBytesSync());
    }
    before = File('${root.path}/app/assets/content.json').readAsStringSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('세 호출 뒤 content.json에 시나리오가 붙고 PR 본문을 돌려준다', () async {
    final body = await run(mock());
    final after = jsonDecode(File('${root.path}/app/assets/content.json').readAsStringSync()) as Map;
    expect(after['version'], ((jsonDecode(before) as Map)['version'] as int) + 1);
    expect([for (final s in after['scenarios'] as List) (s as Map)['id']], contains('A-umbrella-09'));

    expect(users, hasLength(3));
    expect(users[0], startsWith(File('../pipeline/prompts/generate.md').readAsStringSync()));
    expect(users[0], contains('A-umbrella-01'), reason: '생성 호출은 같은 매너의 기존 시나리오를 본다');
    expect(users[1], startsWith(File('../pipeline/prompts/blind.md').readAsStringSync()));
    expect(users[1], contains('A-umbrella-09'));
    expect(users[1], isNot(contains('"grade"')), reason: '블라인드 호출에는 정답이 없다');
    expect(users[1], isNot(contains('"feedback"')));
    expect(users[2], startsWith(File('../pipeline/prompts/judge.md').readAsStringSync()));
    expect(users[2], contains('"grade"'), reason: '판정 호출은 원래 문제를 본다');
    expect(users[2], contains('블라인드답'));

    expect(body, contains('| `A-umbrella-09` | 형식 | 메모 |'));
    expect(body, contains('https://example.test/run/1'));
    expect(body, contains('abc1234'));
    expect(body, contains('valid'));
    expect(body, contains('10/5/0/7'));
    expect(body, contains('펼친 문제 1개'));
  });

  test('열린 content/ PR이 있으면 호출 없이 실패한다', () async {
    final client = mock();
    await expectLater(
      run(client, open: [
        {'head': {'ref': 'content/manner-2-1'}},
      ]),
      throwsA(isA<Exception>()),
    );
    expect(users, isEmpty);
    expect(File('${root.path}/app/assets/content.json').readAsStringSync(), before);
  });

  test('코드 검사가 실패하면 블라인드·판정을 부르지 않고 실패한다', () async {
    await expectLater(run(mock(), check: () => throw Exception('검사 오류')), throwsA(isA<Exception>()));
    expect(users, hasLength(1));
  });

  test('판정 응답이 JSON이 아니면 실패한다', () async {
    await expectLater(run(mock(judge: '표시 없음')), throwsA(isA<FormatException>()));
  });

  group('modelJson', () {
    test('앞뒤 글과 코드 블록 표시를 떼고 읽는다', () {
      expect(modelJson('설명\n```json\n{"a": [1]}\n```\n끝'), {'a': [1]});
      expect(modelJson('[{"id": "x"}] 이상'), [{'id': 'x'}]);
    });
    test('JSON이 없으면 FormatException', () {
      expect(() => modelJson('없다'), throwsFormatException);
    });
  });
}
