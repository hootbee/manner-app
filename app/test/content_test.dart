import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';

void main() {
  final content = parseContent(File('assets/content.json').readAsStringSync());
  List<Map<String, Object?>> expanded(String baseId) =>
      expand(content.scenarios.firstWhere((s) => s['id'] == baseId));

  test('A-sidewalk는 축 key로 8개 id가 펼쳐진다', () {
    final ids = expanded('A-sidewalk').map((s) => s['id']).toList();
    expect(ids, hasLength(8));
    expect(ids.toSet(), hasLength(8));
    expect(ids, contains('A-sidewalk~partner.right'));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^A-sidewalk~[a-z0-9-]+\.[a-z0-9-]+$')));
    }
  });

  test('A-stairs~grandma.up은 보기의 feedback과 area를 받고 자리 표시가 채워진다', () {
    final s = expanded('A-stairs').firstWhere((s) => s['id'] == 'A-stairs~grandma.up');
    final feedback = s['feedback'] as Map;
    expect(feedback['title'], '오를 땐 한 칸 아래, 뒤에서');
    expect(feedback['why'], '할머니가 뒤로 넘어지면 아래에서 받쳐 줄 수 있어요.');
    expect(s['prompt'], '할머니와 계단을 올라간다. 나는 어디에 있을까?');
    expect(s['area'], '어른·가족');
  });

  test('받침 있는 낱말 뒤에는 받침용 조사가 붙는다', () {
    final sidewalk = expanded('A-sidewalk').firstWhere((s) => s['id'] == 'A-sidewalk~partner.right');
    expect(sidewalk['prompt'], startsWith('연인과 인도를 걷는다.'));
    final stairs = expanded('A-stairs').firstWhere((s) => s['id'] == 'A-stairs~boss.up');
    expect((stairs['feedback'] as Map)['why'], contains('팀장님이'));
  });

  test('보기의 area, feedback이 기본값을 덮어쓴다', () {
    final [s] = expand({
      'id': 'X',
      'area': '친구',
      'feedback': {'title': '기본', 'why': '기본'},
      'vary': [
        [
          {
            'key': 'a',
            'area': '직장',
            'feedback': {'title': '보기', 'why': '보기'},
          },
        ],
      ],
    });
    expect(s['area'], '직장');
    expect(s['feedback'], {'title': '보기', 'why': '보기'});
  });

  test('vary가 없으면 기본 id 하나다', () {
    expect(expanded('A-crosswalk-01').map((s) => s['id']), ['A-crosswalk-01']);
  });
}
