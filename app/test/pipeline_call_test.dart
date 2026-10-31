import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/pipeline.dart';

// Messages API 호출 (ADR 0009 §5, §8, §9, 작업 A7). 네트워크는 MockClient만 쓴다. 키는 더미다.
const _key = 'test-key-dummy';

http.Response _ok(
  List<Map<String, Object?>> content, {
  String stop = 'end_turn',
  Map<String, Object?>? usage,
}) => http.Response(
  jsonEncode({
    'content': content,
    'stop_reason': stop,
    'usage': usage ?? {'input_tokens': 1, 'output_tokens': 2},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late int calls;
  late http.Request sent;
  MockClient mock(http.Response Function(http.Request) reply) =>
      MockClient((r) async {
        calls++;
        sent = r;
        return reply(r);
      });

  setUp(() => calls = 0);

  Future<({String text, Map<String, int> usage})> call(
    http.Client c, {
    String user = '문제를 만들어라',
  }) => callClaude(c, apiKey: _key, system: '시스템', user: user);

  test(
    '요청: URL, 헤더, 본문(model, max_tokens, 최상위 cache_control, system, messages)',
    () async {
      await call(
        mock(
          (_) => _ok([
            {'type': 'text', 'text': '{}'},
          ]),
        ),
      );
      expect(calls, 1);
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], _key);
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.headers['content-type'], startsWith('application/json'));
      final body = jsonDecode(sent.body) as Map<String, Object?>;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['max_tokens'], 16000);
      expect(body['cache_control'], {'type': 'ephemeral'});
      expect(body['system'], '시스템');
      expect(body['messages'], [
        {'role': 'user', 'content': '문제를 만들어라'},
      ]);
      expect(body.containsKey('output_config'), isFalse);
    },
  );

  test('text 블록만 이어 붙이고 다른 블록은 무시한다. usage 네 값을 돌려준다', () async {
    final r = await call(
      mock(
        (_) => _ok(
          [
            {'type': 'thinking', 'thinking': '생각', 'signature': 'x'},
            {'type': 'text', 'text': '{"a":'},
            {'type': 'tool_use', 'id': 't', 'name': 'n', 'input': {}},
            {'type': 'text', 'text': '1}'},
          ],
          usage: {
            'input_tokens': 10,
            'cache_creation_input_tokens': 20,
            'cache_read_input_tokens': 30,
            'output_tokens': 40,
          },
        ),
      ),
    );
    expect(r.text, '{"a":1}');
    expect(r.usage, {
      'input_tokens': 10,
      'cache_creation_input_tokens': 20,
      'cache_read_input_tokens': 30,
      'output_tokens': 40,
    });
  });

  test('usage에 캐시 항목이 없으면 0이다', () async {
    final r = await call(
      mock(
        (_) => _ok([
          {'type': 'text', 'text': 'x'},
        ]),
      ),
    );
    expect(r.usage, {
      'input_tokens': 1,
      'cache_creation_input_tokens': 0,
      'cache_read_input_tokens': 0,
      'output_tokens': 2,
    });
  });

  test('stop_reason이 end_turn이 아니면 예외다 (max_tokens)', () async {
    final c = mock(
      (_) => _ok([
        {'type': 'text', 'text': '잘림'},
      ], stop: 'max_tokens'),
    );
    await expectLater(
      call(c),
      throwsA(
        isA<Exception>().having((e) => '$e', 'msg', contains('max_tokens')),
      ),
    );
    expect(calls, 1);
  });

  for (final status in [429, 529, 500, 400]) {
    test('HTTP $status면 다시 보내지 않고 예외다', () async {
      final c = mock((_) => http.Response('{"error":{"type":"x"}}', status));
      await expectLater(
        call(c),
        throwsA(
          isA<Exception>().having((e) => '$e', 'msg', contains('$status')),
        ),
      );
      expect(calls, 1);
    });
  }

  test('본문이 한도를 넘으면 요청을 보내지 않고 예외다', () async {
    final c = mock(
      (_) => _ok([
        {'type': 'text', 'text': 'x'},
      ]),
    );
    await expectLater(
      call(c, user: 'a' * maxRequestBytes),
      throwsA(isA<Exception>()),
    );
    expect(calls, 0);
  });

  test('한도 상수는 200KB(200 * 1024)다', () {
    expect(maxRequestBytes, 200 * 1024);
  });

  // 구현이 재는 방식 그대로: utf8.encode(jsonEncode(요청 본문)). 'a'는 JSON에서 한 바이트다.
  int bodyBytes(String user) => utf8
      .encode(
        jsonEncode({
          'model': claudeModel,
          'max_tokens': 16000,
          'cache_control': {'type': 'ephemeral'},
          'system': '시스템',
          'messages': [
            {'role': 'user', 'content': user},
          ],
        }),
      )
      .length;

  test('본문이 정확히 한도(200 * 1024바이트)면 보낸다', () async {
    final user = 'a' * (200 * 1024 - bodyBytes(''));
    expect(bodyBytes(user), 200 * 1024);
    await call(
      mock(
        (_) => _ok([
          {'type': 'text', 'text': 'x'},
        ]),
      ),
      user: user,
    );
    expect(calls, 1);
  });

  test('본문이 한도보다 1바이트 크면 보내지 않고 예외다', () async {
    final user = 'a' * (200 * 1024 - bodyBytes('') + 1);
    expect(bodyBytes(user), 200 * 1024 + 1);
    await expectLater(
      call(
        mock(
          (_) => _ok([
            {'type': 'text', 'text': 'x'},
          ]),
        ),
        user: user,
      ),
      throwsA(isA<Exception>()),
    );
    expect(calls, 0);
  });

  test('한도는 바이트(utf8)로 센다: 글자 수는 한도 안이어도 바이트가 넘으면 거부한다', () async {
    final c = mock(
      (_) => _ok([
        {'type': 'text', 'text': 'x'},
      ]),
    );
    await expectLater(
      call(c, user: '가' * (maxRequestBytes ~/ 2)),
      throwsA(isA<Exception>()),
    );
    expect(calls, 0);
  });

  // 빈 키면 오류 메시지의 키 치환 replaceAll('', '***')이 글자마다 ***를 끼운다. 보내기 전에 막는다.
  for (final blank in ['', '   ', '\n\t']) {
    test('apiKey가 비었거나 공백뿐이면(${jsonEncode(blank)}) 요청을 보내지 않고 예외다', () async {
      final c = mock(
        (_) => _ok([
          {'type': 'text', 'text': 'x'},
        ]),
      );
      await expectLater(
        callClaude(c, apiKey: blank, system: '시스템', user: '문제를 만들어라'),
        throwsA(
          isA<Exception>().having((e) => '$e', 'msg', contains('키')),
        ),
      );
      expect(calls, 0);
    });
  }

  test('예외 메시지에 키 값이 없다 (오류 응답이 키를 되풀이해도)', () async {
    final failures = <String>[
      for (final reply in <http.Response>[
        http.Response('bad $_key', 429),
        _ok([
          {'type': 'text', 'text': 'x'},
        ], stop: 'max_tokens'),
      ])
        await call(
          mock((_) => reply),
        ).then((_) => '', onError: (Object e) => '$e'),
    ];
    for (final m in failures) {
      expect(m, isNotEmpty);
      expect(m, isNot(contains(_key)));
    }
    final big = await call(
      mock((_) => http.Response('', 200)),
      user: 'a' * maxRequestBytes,
    ).then((_) => '', onError: (Object e) => '$e');
    expect(big, isNotEmpty);
    expect(big, isNot(contains(_key)));
  });
}
