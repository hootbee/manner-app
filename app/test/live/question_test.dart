// 펼친 문제 → 화면 문제와 채점(ADR 0003 §3, ADR 0002 §2). 콘텐츠 PR로 깨지지 않게 인라인 콘텐츠를 쓴다.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/live/question.dart';

const _feedback = {'title': '제목', 'why': '이유'};
const _source = {'title': '출처', 'publisher': '기관', 'date': '2026-10-27', 'locator': '1쪽', 'url': 'https://example.test'};

final c = parseContent(jsonEncode({
  'schema': 1,
  'version': 1,
  'principles': [
    {'id': 'A', 'name': '원칙', 'motto': '모토'},
  ],
  'manners': [
    {'id': 1, 'name': '매너1', 'principle': 'A', 'places': <String>[]},
  ],
  'scenarios': [
    {
      'id': 'P',
      'manner': 1,
      'format': 'position',
      'template': 'sidewalk',
      'prompt': '{other와} 걷는다',
      'spots': [
        {'id': 'inner', 'label': '안쪽'},
        {'id': 'outer', 'label': '바깥쪽'},
      ],
      'answer': 'outer',
      'feedback': _feedback,
      'evidence': {
        'summary': '요약',
        'sources': [_source, _source],
      },
      'vary': [
        [
          {'key': 'partner', 'area': '연애', 'vars': {'other': '연인'}},
        ],
        [
          {'key': 'right', 'vars': {'mirror': false, 'side': '오른쪽'}},
          {'key': 'left', 'vars': {'mirror': true, 'side': '왼쪽'}},
        ],
      ],
    },
    {
      'id': 'C',
      'manner': 1,
      'format': 'choice',
      'area': '연애',
      'prompt': '고른다',
      'options': [
        {'text': '최선', 'grade': 'best'},
        {'text': '괜찮음', 'grade': 'ok', 'note': '메모'},
        {'text': '피함', 'grade': 'avoid'},
        {'text': '또 피함', 'grade': 'avoid'},
      ],
      'feedback': _feedback,
      'evidence': {'summary': '출처 없음', 'sources': <Object>[]},
    },
    {'id': 'X', 'manner': 1, 'format': 'ox', 'area': '공공장소', 'prompt': '맞나', 'answer': false, 'feedback': _feedback},
    {
      'id': 'O',
      'manner': 1,
      'format': 'order',
      'area': '어른·가족',
      'prompt': '순서대로',
      'cards': ['첫째', '둘째', '셋째'],
      'feedback': _feedback,
    },
  ],
  'days': <Object>[],
}));

void main() {
  final rng = Random(0);

  test('position: P~partner.left는 vars.mirror가 축 값(true)이고 me는 "나", other는 vars.other다', () {
    final s = Shown(c, 'P~partner.left', rng);
    final q = s.q as PositionQuestion;
    expect([q.area, q.prompt, q.template, q.me, q.other, q.vars['mirror'], q.vars['side']],
        ['연애', '연인과 걷는다', 'sidewalk', '나', '연인', true, '왼쪽']);
    expect(q.motto, '모토');
    expect(q.spots.map((p) => p.id), ['inner', 'outer']);
    expect(s.grade(const PickSpot('outer')), Grade.best);
    expect(s.grade(const PickSpot('inner')), Grade.avoid);
    final e = s.explain(Grade.best, 10, 1);
    expect([e.title, e.why, e.correct, e.options, e.evidence?.sources.length], ['제목', '이유', ['outer'], isEmpty, 2]);
  });

  test('choice: 보기 id는 배열 순번이고 섞여 나온다. 채점은 고른 보기의 grade이고 해설에 보기별 grade와 note가 있다', () {
    final s = Shown(c, 'C', rng);
    final q = s.q as ChoiceQuestion;
    expect({for (final o in q.options) o.id: o.text}, {'0': '최선', '1': '괜찮음', '2': '피함', '3': '또 피함'});
    expect([s.grade(const PickOption('0')), s.grade(const PickOption('1')), s.grade(const PickOption('2'))],
        [Grade.best, Grade.ok, Grade.avoid]);
    final e = s.explain(Grade.ok, 5, 0);
    expect(e.correct, ['0']);
    expect(e.options['1'], (grade: Grade.ok, note: '메모'));
    expect(e.evidence, isNull); // sources가 비었다
  });

  test('ox: answer가 false면 correct는 x이고 PickOx(false)가 best다', () {
    final s = Shown(c, 'X', rng);
    expect(s.q, isA<OxQuestion>());
    expect([s.explain(Grade.best, 10, 1).correct, s.grade(const PickOx(false)), s.grade(const PickOx(true))],
        [['x'], Grade.best, Grade.avoid]);
  });

  test('order: 카드 id는 맞는 순서의 순번이다. 모두 맞으면 best, 하나라도 틀리면 avoid', () {
    final s = Shown(c, 'O', rng);
    final q = s.q as OrderQuestion;
    expect({for (final o in q.cards) o.id: o.text}, {'0': '첫째', '1': '둘째', '2': '셋째'});
    expect(s.grade(const PlaceOrder(['0', '1', '2'])), Grade.best);
    expect(s.grade(const PlaceOrder(['1', '0', '2'])), Grade.avoid);
  });
}
