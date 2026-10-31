import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/validate.dart';

const _fb = {'title': 't', 'why': 'w'};

/// 장면용 매너 [m]의 ox 문제 3개(기본 시나리오 3개 경고를 피한다).
List<Map<String, Object>> _ox(int m) => [
      for (var i = 1; i <= 3; i++)
        {'id': 'ox-$m-$i', 'manner': m, 'format': 'ox', 'area': '친구', 'prompt': 'p', 'answer': true, 'feedback': _fb},
    ];

/// 오류도 경고도 없는 가장 작은 콘텐츠. 매너 1에 기본 시나리오 3개, 펼친 문제 3개.
/// 하루의 장면 매너는 서로 달라야 하므로 매너 11·12에 ox 문제 3개씩을 둔다.
final _fixture = {
  'schema': 1,
  'version': 1,
  'principles': [
    {'id': 'A'},
  ],
  'manners': [
    {'id': 1, 'principle': 'A'},
    {'id': 11, 'principle': 'A'},
    {'id': 12, 'principle': 'A'},
  ],
  'scenarios': [
    {
      'id': 'ox-1',
      'manner': 1,
      'format': 'ox',
      'area': '친구',
      'prompt': 'p',
      'answer': true,
      'feedback': _fb,
    },
    {
      'id': 'choice-1',
      'manner': 1,
      'format': 'choice',
      'area': '친구',
      'prompt': 'p',
      'options': [
        {'text': '짧다', 'grade': 'best'},
        {'text': '조금 더 길다', 'grade': 'avoid'},
      ],
      'feedback': _fb,
    },
    {
      'id': 'pos-1',
      'manner': 1,
      'format': 'position',
      'template': 'stairs',
      'prompt': '{other와} 계단',
      'spots': [
        {'id': 'above', 'label': '위'},
        {'id': 'below', 'label': '아래'},
      ],
      'answer': 'below',
      'feedback': _fb,
      'vary': [
        [
          {
            'key': 'dad',
            'area': '어른·가족',
            'vars': {'other': '아버지'},
          },
        ],
      ],
    },
    ..._ox(11),
    ..._ox(12),
  ],
  'days': [
    {
      'id': 'day-01',
      'title': 't',
      'scenes': [
        {'time': '08:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 1},
        {'time': '12:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 11},
        {'time': '18:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 12},
      ],
    },
  ],
};

/// 견본을 복사해 [edit]로 고친 뒤 검사한 결과를 `오류: …`/`경고: …` 문자열로 돌려준다.
List<String> run([void Function(dynamic c)? edit]) {
  final c = jsonDecode(jsonEncode(_fixture));
  edit?.call(c);
  return validate(parseContent(jsonEncode(c))).map((i) => '$i').toList();
}

dynamic scenario(dynamic c, String id) =>
    (c['scenarios'] as List).firstWhere((s) => s['id'] == id);

Matcher has(String prefix) => anyElement(startsWith(prefix));

void main() {
  test('견본은 오류도 경고도 없다', () {
    expect(run(), isEmpty);
  });

  test('장면이 콘텐츠에 없는 매너 99를 가리키면 오류다', () {
    expect(run((c) => c['days'][0]['scenes'][1]['manner'] = 99),
        has('오류: 없는 매너: day-01 장면 1 → 99'));
  });

  group('현재 assets/content.json', () {
    final issues = validate(parseContent(File('assets/content.json').readAsStringSync()));
    test('오류가 없다', () {
      expect(issues.where((i) => i.error), isEmpty);
    });
    test('금지 낱말 오류가 없다', () {
      expect(issues.map((i) => '$i'), isNot(has('오류: 금지 낱말')));
    });
  });

  test('CLI는 오류가 없으면 0, 있으면 1로 끝난다', () async {
    Future<int> cli(String file) async =>
        (await Process.run('dart', ['run', 'tool/validate_content.dart', file])).exitCode;
    expect(await cli('assets/content.json'), 0);

    final dir = Directory.systemTemp.createTempSync('validate_content');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = jsonDecode(File('assets/content.json').readAsStringSync());
    c['days'][0]['scenes'][0]['manner'] = 99;
    final bad = File('${dir.path}/bad.json')..writeAsStringSync(jsonEncode(c));
    expect(await cli(bad.path), 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('--previous 비교', () {
    /// [prev]와 [next]로 고친 두 견본을 비교한 결과.
    List<String> diff(void Function(dynamic c) prev, void Function(dynamic c) next) {
      Content load(void Function(dynamic c) edit) {
        final c = jsonDecode(jsonEncode(_fixture));
        edit(c);
        return parseContent(jsonEncode(c));
      }

      return compare(load(prev), load(next)).map((i) => '$i').toList();
    }

    void same(dynamic c) {}
    void bump(dynamic c) => c['version'] = 2;

    test('내용과 version이 같으면 통과한다', () {
      expect(diff(same, same), isEmpty);
    });
    test('매너·기본 시나리오·펼친 문제·데일리 id가 사라지면 오류다', () {
      final out = diff((c) {
        c['manners'].add({'id': 2, 'principle': 'A'});
        c['scenarios'].add({...scenario(c, 'ox-1'), 'id': 'ox-2'});
        scenario(c, 'pos-1')['vary'][0].add({
          'key': 'mom',
          'vars': {'other': '어머니'},
        });
        c['days'].add({...c['days'][0], 'id': 'day-02'});
      }, bump);
      expect(out, has('오류: 사라진 id: 매너 2'));
      expect(out, has('오류: 사라진 id: 시나리오 ox-2'));
      expect(out, has('오류: 사라진 id: 펼친 문제 pos-1~mom'));
      expect(out, has('오류: 사라진 id: 데일리 day-02'));
    });
    test('은퇴는 사라진 것이 아니다', () {
      expect(
        diff(same, (c) {
          bump(c);
          c['manners'][0]['retired'] = true;
          scenario(c, 'ox-1')['retired'] = true;
          scenario(c, 'pos-1')['vary'][0][0]['retired'] = true;
          c['days'][0]['retired'] = true;
        }),
        isEmpty,
      );
    });
    test('같은 id인 시나리오의 manner가 바뀌면 오류다', () {
      expect(
        diff(same, (c) {
          bump(c);
          c['manners'].add({'id': 2, 'principle': 'A'});
          scenario(c, 'ox-1')['manner'] = 2;
        }),
        has('오류: 매너 바뀜: 시나리오 ox-1 1 → 2'),
      );
    });
    test('매너·시나리오·보기·데일리를 더하고 version을 올리면 통과한다', () {
      expect(
        diff(same, (c) {
          bump(c);
          c['manners'].add({'id': 2, 'principle': 'A'});
          c['scenarios'].add({...scenario(c, 'ox-1'), 'id': 'ox-2', 'manner': 2});
          scenario(c, 'pos-1')['vary'][0].add({
            'key': 'mom',
            'vars': {'other': '어머니'},
          });
          c['days'].add({...c['days'][0], 'id': 'day-02'});
        }),
        isEmpty,
      );
    });
    test('내용이 다른데 version이 크지 않으면 오류다', () {
      final edits = <String, void Function(dynamic c)>{
        '시나리오 문구': (c) => scenario(c, 'ox-1')['prompt'] = 'q',
        '데일리 문구': (c) => c['days'][0]['title'] = 'u',
        '매너 필드': (c) => c['manners'][0]['name'] = 'n',
        '원칙 필드': (c) => c['principles'][0]['name'] = 'n',
        'schema': (c) => c['schema'] = 2,
      };
      for (final MapEntry(key: what, value: edit) in edits.entries) {
        expect(diff(same, edit), ['오류: version이 크지 않음: 1 → 1'], reason: what);
        expect(diff(bump, edit), ['오류: version이 크지 않음: 2 → 1'], reason: what);
        expect(
            diff(same, (c) {
              edit(c);
              bump(c);
            }),
            isEmpty,
            reason: what);
      }
    });
    test('version이 줄면 내용이 같아도 오류다', () {
      expect(diff(bump, same), ['오류: version이 크지 않음: 2 → 1']);
    });
  });

  test('CLI --previous: A-alley~child를 지우면 오류 이름과 id를 출력하고 1로 끝난다', () async {
    final dir = Directory.systemTemp.createTempSync('validate_content');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = jsonDecode(File('assets/content.json').readAsStringSync());
    (scenario(c, 'A-alley')['vary'][0] as List).removeWhere((o) => o['key'] == 'child');
    final next = File('${dir.path}/next.json')..writeAsStringSync(jsonEncode(c));

    Future<ProcessResult> cli(String file) => Process.run(
        'dart', ['run', 'tool/validate_content.dart', file, '--previous=assets/content.json']);
    final r = await cli(next.path);
    expect(r.stdout, contains('오류: 사라진 id: 펼친 문제 A-alley~child'));
    expect(r.exitCode, 1);
    expect((await cli('assets/content.json')).exitCode, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('checkSources (ADR 0009 §6)', () {
    const doc = {
      'publisher': '기관',
      'title': '문서',
      'date': '2026',
      'url': 'https://a.test',
      'manners': [1],
      'summary': '요약',
    };
    const source = {'title': '문서', 'publisher': '기관', 'date': '2026', 'url': 'https://a.test'};
    const mismatch = ['오류: 색인과 맞지 않는 출처: ox-1 https://a.test'];

    /// 견본 ox-1(매너 1)의 출처를 [sources]로 두고 [index]와 대조한 결과.
    List<String> check(List<Json> index, [List<Object> sources = const [source]]) {
      final c = jsonDecode(jsonEncode(_fixture));
      scenario(c, 'ox-1')['evidence'] = {'summary': 's', 'sources': sources};
      return checkSources(parseContent(jsonEncode(c)), index).map((i) => '$i').toList();
    }

    test('색인 항목과 url·publisher·title·date가 같으면 통과한다', () {
      expect(check([doc]), isEmpty);
    });
    test('빈 sources는 통과한다', () {
      expect(check([], []), isEmpty);
      expect(check([doc], []), isEmpty);
    });
    test('색인에 없는 url을 가진 출처는 오류다', () {
      expect(check([]), mismatch);
      expect(check([doc], [{...source, 'url': 'https://b.test'}]), ['오류: 색인과 맞지 않는 출처: ox-1 https://b.test']);
    });
    test('매너 4에만 묶인 문서를 매너 1 시나리오가 들면 오류다', () {
      expect(check([{...doc, 'manners': [4]}]), mismatch);
    });
    test('매너와 네 칸은 같은 색인 항목에서 맞아야 한다', () {
      final b = {...source, 'url': 'https://b.test'};
      expect(check([doc, {...doc, ...b, 'manners': [4]}], [b]), ['오류: 색인과 맞지 않는 출처: ox-1 https://b.test']);
    });
    test('은퇴한 시나리오의 출처도 대조한다(모든 시나리오)', () {
      final c = jsonDecode(jsonEncode(_fixture));
      scenario(c, 'ox-1')
        ..['retired'] = true
        ..['evidence'] = {'summary': 's', 'sources': [source]};
      expect(checkSources(parseContent(jsonEncode(c)), []).map((i) => '$i'), mismatch);
    });
    test('publisher나 title(그리고 date)이 색인과 다르면 오류다', () {
      expect(check([doc], [{...source, 'publisher': '다른 기관'}]), mismatch);
      expect(check([doc], [{...source, 'title': '다른 문서'}]), mismatch);
      expect(check([doc], [{...source, 'date': '2025'}]), mismatch);
    });
    test('색인 항목에 필수 칸이 없거나 비면 오류다', () {
      expect(check([{...doc}..remove('publisher')], []), ['오류: publisher 없음: 색인 0']);
      expect(check([{...doc}..remove('summary')], []), ['오류: summary 없음: 색인 0']);
      expect(check([doc, {...doc, 'title': ' '}], []), ['오류: title 없음: 색인 1']);
      expect(check([{...doc, 'manners': []}], []), ['오류: manners 없음: 색인 0']);
      expect(check([{}], []), [
        for (final k in ['publisher', 'title', 'date', 'url', 'manners', 'summary']) '오류: $k 없음: 색인 0',
      ]);
    });
    test('summary가 1,001자면 오류다(1,000자는 통과). 글자 수는 코드 포인트로 센다', () {
      expect(check([{...doc, 'summary': '가' * 1000}]), isEmpty);
      expect(check([{...doc, 'summary': '😀' * 1000}]), isEmpty); // UTF-16 코드 단위로는 2,000
      expect(check([{...doc, 'summary': '가' * 1001}]), ['오류: summary 1,000자 초과: 색인 0 (1001자)']);
    });
  });

  test('CLI --sources: 출처가 색인과 맞지 않으면 오류를 출력하고 1, 맞으면 0으로 끝난다', () async {
    final dir = Directory.systemTemp.createTempSync('validate_content');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = File('${dir.path}/sources.json')..writeAsStringSync('[]');
    final c = jsonDecode(File('assets/content.json').readAsStringSync());
    for (final s in c['scenarios']) {
      s.remove('evidence');
    }
    final ok = File('${dir.path}/ok.json')..writeAsStringSync(jsonEncode(c));
    final s = c['scenarios'][0];
    s['evidence'] = {
      'summary': 's',
      'sources': [
        {'title': 't', 'publisher': 'p', 'date': '2026', 'url': 'https://a.test'},
      ],
    };
    final bad = File('${dir.path}/bad.json')..writeAsStringSync(jsonEncode(c));

    Future<ProcessResult> cli(String file) =>
        Process.run('dart', ['run', 'tool/validate_content.dart', file, '--sources=${index.path}']);
    expect((await cli(ok.path)).exitCode, 0);
    // 모르는 플래그(오타)는 조용히 무시하지 않는다.
    final typo = await Process.run('dart', ['run', 'tool/validate_content.dart', ok.path, '--source=${index.path}']);
    expect(typo.stderr, contains('--source='));
    expect(typo.exitCode, 1);
    final r = await cli(bad.path);
    expect(r.stdout, contains('오류: 색인과 맞지 않는 출처: ${s['id']} https://a.test'));
    expect(r.exitCode, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  group('id 중복', () {
    test('매너', () {
      expect(run((c) => c['manners'].add({'id': 1, 'principle': 'A'})), has('오류: 중복 id: 매너 1'));
    });
    test('기본 시나리오', () {
      expect(run((c) => c['scenarios'].add(scenario(c, 'ox-1'))), has('오류: 중복 id: 시나리오 ox-1'));
    });
    test('데일리', () {
      expect(run((c) => c['days'].add(c['days'][0])), has('오류: 중복 id: 데일리 day-01'));
    });
    test('원칙', () {
      expect(run((c) => c['principles'].add({'id': 'A'})), has('오류: 중복 id: 원칙 A'));
    });
    test('축 안 key', () {
      expect(
        run((c) => scenario(c, 'pos-1')['vary'][0].add({
              'key': 'dad',
              'vars': {'other': '아빠'},
            })),
        has('오류: 중복 key: pos-1 축 0 dad'),
      );
    });
    test('다른 축의 같은 key는 오류가 아니다', () {
      expect(
        run((c) => scenario(c, 'pos-1')['vary'].add([
              {'key': 'dad'},
            ])),
        isEmpty,
      );
    });
    test('펼친 문제 id', () {
      expect(
        run((c) => c['scenarios'].add({...scenario(c, 'ox-1'), 'id': 'pos-1~dad'})),
        has('오류: 중복 id: 펼친 문제 pos-1~dad'),
      );
    });
  });

  group('참조', () {
    test('시나리오의 manner', () {
      expect(run((c) => scenario(c, 'ox-1')['manner'] = 99), has('오류: 없는 매너: 시나리오 ox-1 → 99'));
    });
    test('매너의 principle', () {
      expect(run((c) => c['manners'][0]['principle'] = 'B'), has('오류: 없는 원칙: 매너 1 → B'));
    });
    test('은퇴하지 않은 데일리의 장면이 은퇴한 매너를 가리키면 오류다', () {
      void edit(dynamic c) {
        c['manners'].add({'id': 2, 'principle': 'A', 'retired': true});
        c['days'][0]['scenes'][2]['manner'] = 2;
      }

      expect(run(edit), has('오류: 은퇴한 매너: day-01 장면 2 → 2'));
      expect(
        run((c) {
          edit(c);
          c['days'][0]['retired'] = true;
        }),
        isEmpty,
      );
    });
    test('하루 안에서 같은 매너가 두 장면에 나오면 오류다 (planDay가 문제를 못 고른다)', () {
      expect(run((c) => c['days'][0]['scenes'][2]['manner'] = 1), has('오류: 장면 매너 중복: day-01 → 1'));
    });
  });

  group('펼친 문제', () {
    test('area가 없으면 오류다', () {
      expect(run((c) => scenario(c, 'ox-1').remove('area')), has('오류: area 없음: ox-1'));
    });
    test('feedback이 없으면 오류다', () {
      expect(run((c) => scenario(c, 'ox-1').remove('feedback')), has('오류: feedback 없음: ox-1'));
    });
    test('채우지 못한 자리 표시가 남으면 오류다', () {
      expect(run((c) => scenario(c, 'ox-1')['prompt'] = '{who} 간다'),
          has('오류: 남은 자리 표시: ox-1 {who}'));
      expect(run((c) => scenario(c, 'pos-1')['feedback']['why'] = '{other랑} 간다'),
          has('오류: 남은 자리 표시: pos-1~dad {other랑}'));
      expect(run((c) => scenario(c, 'choice-1')['options'][0]['text'] = '{who} 간다'),
          has('오류: 남은 자리 표시: choice-1 {who}'));
    });
    test('position에 vars.other가 없으면 오류다', () {
      expect(run((c) => scenario(c, 'pos-1')['vary'][0][0].remove('vars')),
          has('오류: vars.other 없음: pos-1~dad'));
    });
    test('position의 answer가 spots에 없으면 오류다', () {
      expect(run((c) => scenario(c, 'pos-1')['answer'] = 'same'),
          has('오류: answer가 spots에 없음: pos-1~dad → same'));
    });
    test('템플릿이 모르는 spot id는 오류다', () {
      expect(run((c) => scenario(c, 'pos-1')['spots'].add({'id': 'roof', 'label': '지붕'})),
          has('오류: 템플릿에 없는 자리: pos-1~dad stairs.roof'));
      expect(run((c) => scenario(c, 'pos-1')['spots'].add({'id': 'wall', 'label': '벽'})),
          has('오류: 템플릿에 없는 자리: pos-1~dad stairs.wall'));
    });
  });

  group('choice', () {
    test('best가 없으면 오류다', () {
      expect(run((c) => scenario(c, 'choice-1')['options'][0]['grade'] = 'ok'),
          has('오류: best가 1개가 아님: choice-1 (0개)'));
    });
    test('best가 둘이면 오류다', () {
      expect(run((c) => scenario(c, 'choice-1')['options'][1]['grade'] = 'best'),
          has('오류: best가 1개가 아님: choice-1 (2개)'));
    });
    test('best 보기가 가장 길면 경고다', () {
      expect(run((c) => scenario(c, 'choice-1')['options'][0]['text'] = '가장 길고 긴 보기 문장'),
          ['경고: best 보기가 가장 김: choice-1']);
    });
    test('best와 같은 길이의 보기가 있으면 경고하지 않는다', () {
      expect(run((c) => scenario(c, 'choice-1')['options'][0]['text'] = '가나다라 마바'), isEmpty);
    });
  });

  group('매너당 문제 수', () {
    test('출제 가능한 펼친 문제가 2개 미만이면 오류, 기본 시나리오가 3개 미만이면 경고다', () {
      expect(
        run((c) {
          scenario(c, 'ox-1')['retired'] = true;
          scenario(c, 'choice-1')['retired'] = true;
        }),
        [
          '오류: 출제 가능한 펼친 문제 2개 미만: 매너 1 (1개)',
          '경고: 출제 가능한 기본 시나리오 3개 미만: 매너 1 (1개)',
        ],
      );
    });
    test('펼친 문제가 2개면 장면을 채우므로 기본 시나리오 경고만 낸다 (ADR 0004: 다시 풀기는 같은 문제)', () {
      expect(run((c) => scenario(c, 'ox-1')['retired'] = true),
          ['경고: 출제 가능한 기본 시나리오 3개 미만: 매너 1 (2개)']);
    });
    test('은퇴한 매너는 문제가 없어도 된다', () {
      expect(run((c) => c['manners'].add({'id': 2, 'principle': 'A', 'retired': true})), isEmpty);
    });
  });

  group('금지 낱말 (ADR 0009 §7)', () {
    const word = '여자친구';

    test('bannedWords는 ADR 첫 목록 그대로다(순서도)', () {
      expect(bannedWords, ['여자친구', '남자친구', '여친', '남친', '여자', '남자', '여성', '남성', '밀당', '꼬시']);
    });

    test('선택지 문장에 있으면 오류다', () {
      expect(run((c) => scenario(c, 'choice-1')['options'][0]['text'] = '$word에게 말한다'),
          anyElement(allOf(startsWith('오류: 금지 낱말: choice-1 '), endsWith(' $word'))));
    });

    test('낱말마다 오류다', () {
      for (final w in bannedWords) {
        expect(run((c) => scenario(c, 'ox-1')['prompt'] = 'a${w}b'), has('오류: 금지 낱말: ox-1 $w'), reason: w);
      }
    });

    test('evidence(출처 제목)에만 있으면 오류가 아니다', () {
      expect(
        run((c) => scenario(c, 'ox-1')['evidence'] = {
              'summary': 's',
              'sources': [
                {'title': '$word 예절', 'publisher': '기관', 'date': '2026', 'url': 'https://a.test'},
              ],
            }),
        isEmpty,
      );
    });

    // 모든 문자열 칸을 담은 견본: 형식 넷(position, choice, ox, order)과 vary 보기의 덮어쓰기.
    void rich(dynamic c) {
      final choice = scenario(c, 'choice-1');
      choice['options'][1]['note'] = '이유';
      // vary 보기의 feedback은 기본 feedback을 덮으므로 기본 feedback이 없는 시나리오를 따로 둔다.
      c['scenarios'].add({
        ...scenario(c, 'pos-1'),
        'id': 'pos-2',
        'vary': [
          [
            {
              'key': 'mom',
              'area': '어른·가족',
              'vars': {'other': '어머니'},
              'feedback': {'title': 'vt', 'why': 'vw'},
            },
          ],
        ],
      }..remove('feedback'));
      c['scenarios'].add({
        'id': 'order-1',
        'manner': 1,
        'format': 'order',
        'area': '친구',
        'prompt': 'p',
        'cards': ['하나', '둘', '셋'],
        'feedback': {..._fb},
      });
    }

    // 말(텍스트)이 아니라 식별자·열거값인 키는 낱말을 심을 칸이 아니다.
    const notText = {'id', 'format', 'template', 'area', 'grade', 'key', 'answer', 'tags', 'evidence'};
    Iterable<List<Object>> leaves(Object? v, [List<Object> path = const []]) => switch (v) {
          String _ => [path],
          List l => [for (var i = 0; i < l.length; i++) ...leaves(l[i], [...path, i])],
          Map m => [
              for (final e in m.entries)
                if (!notText.contains(e.key)) ...leaves(e.value, [...path, e.key as Object]),
            ],
          _ => const [],
        };

    final richContent = jsonDecode(jsonEncode(_fixture));
    rich(richContent);
    final cells = [
      for (final s in richContent['scenarios'] as List)
        for (final p in leaves(s)) (s['id'] as String, p),
    ];

    test('견본에는 금지 낱말이 없다', () {
      expect(run(rich), isNot(has('오류: 금지 낱말')));
    });

    test('훑은 칸이 content.schema.json의 문자열 칸을 모두 덮는다', () {
      final defs = (jsonDecode(File('assets/content.schema.json').readAsStringSync()) as Map)['definitions'] as Map;
      bool isText(Object? p) => p is Map && ((p[r'$ref'] ?? (p['items'] as Map?)?[r'$ref']) as String?)?.endsWith('/text') == true;
      final fields = {
        for (final d in ['scenario', 'feedback', 'spot', 'choiceOption'])
          for (final e in ((defs[d] as Map)['properties'] as Map).entries)
            if (isText(e.value)) e.key,
      };
      final seen = {for (final (_, p) in cells) ...p.map((x) => '$x')};
      expect(fields, containsAll(['prompt', 'cards', 'title', 'why', 'label', 'text', 'note']));
      expect(seen, containsAll(fields));
      expect(seen, containsAll(['vars', 'other'])); // vary 보기의 vars
    });

    for (final (sid, path) in cells) {
      test('$sid ${path.join('.')}', () {
        expect(
          run((c) {
            rich(c);
            dynamic node = scenario(c, sid);
            for (final k in path.take(path.length - 1)) {
              node = node[k];
            }
            node[path.last] = 'a${word}b';
          }),
          anyElement(allOf(startsWith('오류: 금지 낱말: $sid'), endsWith(' $word'))),
        );
      });
    }
  });
}
