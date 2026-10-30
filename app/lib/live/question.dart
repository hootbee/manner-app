// 펼친 문제(ADR 0003 §3)를 화면 문제와 해설(ADR 0002 §2)로 옮기고 답을 채점한다.
// 채점: choice는 고른 보기의 grade, 나머지는 correct와 같으면 best 아니면 avoid(순서는 하나라도 틀리면 avoid).
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../backend.dart';
import '../content/content.dart';

/// 세트에 낸 문제 하나. choice 보기와 order 카드는 배열 순번을 id로 붙이고 만들 때 한 번 섞는다(다시 풀기도 같은 순서).
class Shown {
  Shown(Content c, this.id, Random rng) {
    final j = c.questions[id]!;
    final manner = c.lookup(id)!.manner;
    final base = (
      area: j['area'] as String,
      prompt: j['prompt'] as String,
      motto: c.principles.firstWhere((p) => p['id'] == manner['principle'])['motto'] as String,
    );
    final feedback = j['feedback'] as Json;
    title = feedback['title'] as String;
    why = feedback['why'] as String;
    final ev = j['evidence'] as Json?;
    final sources = ((ev?['sources'] as List?) ?? const []).cast<Json>();
    evidence = sources.isEmpty
        ? null
        : Evidence(summary: ev!['summary'] as String, sources: [
            for (final s in sources)
              Source(
                title: s['title'] as String,
                publisher: s['publisher'] as String,
                date: s['date'] as String,
                locator: s['locator'] as String?,
                url: s['url'] as String,
              ),
          ]);

    switch (j['format']) {
      case 'position':
        final vars = Map<String, Object>.from((j['vars'] as Map?) ?? const {});
        correct = [j['answer'] as String];
        q = PositionQuestion(
          area: base.area,
          prompt: base.prompt,
          motto: base.motto,
          template: j['template'] as String,
          me: '나', // ADR 0003 §3: 늘 "나", 앱 상수
          other: vars['other'] as String,
          vars: vars,
          spots: [for (final s in (j['spots'] as List).cast<Json>()) Spot(s['id'] as String, s['label'] as String)],
        );
      case 'choice':
        final opts = (j['options'] as List).cast<Json>();
        options = {
          for (final (i, o) in opts.indexed)
            '$i': (grade: Grade.values.byName(o['grade'] as String), note: o['note'] as String?),
        };
        correct = [for (final e in options.entries) if (e.value.grade == Grade.best) e.key];
        q = ChoiceQuestion(
          area: base.area,
          prompt: base.prompt,
          motto: base.motto,
          options: [for (final (i, o) in opts.indexed) Option('$i', o['text'] as String)]..shuffle(rng),
        );
      case 'ox':
        correct = [j['answer'] == true ? 'o' : 'x'];
        q = OxQuestion(area: base.area, prompt: base.prompt, motto: base.motto);
      case 'order':
        final cards = (j['cards'] as List).cast<String>();
        correct = [for (var i = 0; i < cards.length; i++) '$i'];
        q = OrderQuestion(
          area: base.area,
          prompt: base.prompt,
          motto: base.motto,
          cards: [for (final (i, t) in cards.indexed) Option('$i', t)]..shuffle(rng),
        );
      default:
        throw FormatException('모르는 문제 형식', j['format']);
    }
  }

  final String id; // 펼친 문제 id = attempts.scenario_id
  late final Question q;
  late final List<String> correct;
  Map<String, ({Grade grade, String? note})> options = const {};
  late final String title, why;
  late final Evidence? evidence;

  Grade grade(Answer a) => switch (a) {
        PickOption(:final id) => options[id]?.grade ?? Grade.avoid,
        PickSpot(:final id) => _match([id]),
        PickOx(:final o) => _match([o ? 'o' : 'x']),
        PlaceOrder(:final ids) => _match(ids),
      };

  Grade _match(List<String> x) => listEquals(x, correct) ? Grade.best : Grade.avoid;

  Explanation explain(Grade grade, int xp, int combo) => Explanation(
        grade: grade,
        xp: xp,
        combo: combo,
        title: title,
        why: why,
        correct: correct,
        options: options,
        evidence: evidence,
      );
}
