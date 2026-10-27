import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/validate.dart';

const _fb = {'title': 't', 'why': 'w'};

/// 오류도 경고도 없는 가장 작은 콘텐츠. 매너 1에 기본 시나리오 3개, 펼친 문제 3개.
const _fixture = {
  'schema': 1,
  'version': 1,
  'principles': [
    {'id': 'A'},
  ],
  'manners': [
    {'id': 1, 'principle': 'A'},
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
  ],
  'days': [
    {
      'id': 'day-01',
      'title': 't',
      'scenes': [
        {'time': '08:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 1},
        {'time': '12:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 1},
        {'time': '18:00', 'title': 't', 'short': 's', 'intro': 'i', 'manner': 1},
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
}
