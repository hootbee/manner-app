// 콘텐츠 검사 (ADR 0003 §6): 파일 하나 검사, --previous 비교, --sources 출처 대조(ADR 0009 §6). 순수 Dart. JSON Schema 검사는 ajv가 따로 한다.
import 'dart:convert';

import 'content.dart';
import 'templates.dart';

class Issue {
  const Issue(this.error, this.message);
  final bool error;
  final String message;

  @override
  String toString() => '${error ? '오류' : '경고'}: $message';
}

final _placeholder = RegExp(r'\{[^{}]*\}');

/// 금지 표현 (ADR 0009 §7). 펼친 문제의 문자열에 들어 있으면 오류다. 예외 표시는 없다.
const bannedWords = <String>['여자친구', '남자친구', '여친', '남친', '여자', '남자', '여성', '남성', '밀당', '꼬시'];

List<Issue> validate(Content c) {
  final out = <Issue>[];
  void err(String m) => out.add(Issue(true, m));
  void warn(String m) => out.add(Issue(false, m));

  void dups(String what, Iterable<Object?> ids) {
    final seen = <Object?>{};
    for (final id in ids) {
      if (!seen.add(id)) err('중복 id: $what $id');
    }
  }

  // 펼친 문제는 Content.questions(Map)가 중복을 덮으므로 직접 펼친다.
  final expanded = [for (final s in c.scenarios) ...expand(s)];

  dups('원칙', c.principles.map((p) => p['id']));
  dups('매너', c.manners.map((m) => m['id']));
  dups('시나리오', c.scenarios.map((s) => s['id']));
  dups('데일리', c.days.map((d) => d['id']));
  dups('펼친 문제', expanded.map((q) => q['id']));
  for (final s in c.scenarios) {
    final vary = (s['vary'] as List?) ?? const [];
    for (var a = 0; a < vary.length; a++) {
      final seen = <Object?>{};
      for (final o in (vary[a] as List).cast<Json>()) {
        if (!seen.add(o['key'])) err('중복 key: ${s['id']} 축 $a ${o['key']}');
      }
    }
  }

  final principles = {for (final p in c.principles) p['id']};
  final manners = {for (final m in c.manners) m['id']: m};
  for (final m in c.manners) {
    if (!principles.contains(m['principle'])) err('없는 원칙: 매너 ${m['id']} → ${m['principle']}');
  }
  for (final s in c.scenarios) {
    if (!manners.containsKey(s['manner'])) err('없는 매너: 시나리오 ${s['id']} → ${s['manner']}');
  }
  for (final d in c.days) {
    final scenes = (d['scenes'] as List).cast<Json>();
    final seen = <Object?>{};
    for (final s in scenes) {
      if (!seen.add(s['manner'])) err('장면 매너 중복: ${d['id']} → ${s['manner']}');
    }
    for (var i = 0; i < scenes.length; i++) {
      final m = scenes[i]['manner'];
      if (!manners.containsKey(m)) {
        err('없는 매너: ${d['id']} 장면 $i → $m');
      } else if (d['retired'] != true && manners[m]!['retired'] == true) {
        err('은퇴한 매너: ${d['id']} 장면 $i → $m');
      }
    }
  }

  for (final q in expanded) {
    final id = q['id'];
    if (q['area'] == null) err('area 없음: $id');
    if (q['feedback'] == null) err('feedback 없음: $id');
    for (final p in {..._strings(q).expand((s) => _placeholder.allMatches(s).map((m) => m[0]))}) {
      err('남은 자리 표시: $id $p');
    }
    // evidence는 출처 제목이라 금지 낱말을 보지 않는다.
    final text = _strings({...q}..remove('evidence')).toList();
    for (final w in bannedWords) {
      if (text.any((s) => s.contains(w))) err('금지 낱말: $id $w');
    }
    switch (q['format']) {
      case 'position':
        if ((q['vars'] as Map?)?['other'] == null) err('vars.other 없음: $id');
        final spots = [for (final s in (q['spots'] as List).cast<Json>()) s['id']];
        if (!spots.contains(q['answer'])) err('answer가 spots에 없음: $id → ${q['answer']}');
        final known = templateSpots[q['template']] ?? const {};
        for (final s in spots) {
          if (!known.contains(s)) err('템플릿에 없는 자리: $id ${q['template']}.$s');
        }
      case 'choice':
        final options = (q['options'] as List).cast<Json>();
        final best = options.where((o) => o['grade'] == 'best').toList();
        if (best.length != 1) {
          err('best가 1개가 아님: $id (${best.length}개)');
        } else {
          final len = (best.single['text'] as String).length;
          // 동점은 "가장 김"으로 보지 않는다.
          if (options.every((o) => o == best.single || (o['text'] as String).length < len)) {
            warn('best 보기가 가장 김: $id');
          }
        }
    }
  }

  for (final m in c.manners) {
    if (m['retired'] == true) continue;
    final qs = c.selectable.where((q) => q['manner'] == m['id']);
    final bases = {for (final q in qs) (q['id'] as String).split('~').first};
    if (qs.length < 2) err('출제 가능한 펼친 문제 2개 미만: 매너 ${m['id']} (${qs.length}개)');
    if (bases.length < 3) warn('출제 가능한 기본 시나리오 3개 미만: 매너 ${m['id']} (${bases.length}개)');
  }
  return out;
}

Iterable<String> _strings(Object? v) => switch (v) {
      String s => [s],
      List l => l.expand(_strings),
      Map m => m.values.expand(_strings),
      _ => const [],
    };

/// `--previous`와 비교한다. 은퇴한 것도 파일에 남으므로 사라진 것이 아니다.
List<Issue> compare(Content prev, Content next) {
  final out = <Issue>[];
  void gone(String what, Iterable<Object?> before, Iterable<Object?> after) {
    final now = after.toSet();
    for (final id in before) {
      if (!now.contains(id)) out.add(Issue(true, '사라진 id: $what $id'));
    }
  }

  gone('매너', prev.manners.map((m) => m['id']), next.manners.map((m) => m['id']));
  gone('시나리오', prev.scenarios.map((s) => s['id']), next.scenarios.map((s) => s['id']));
  gone('펼친 문제', prev.questions.keys, next.questions.keys);
  gone('데일리', prev.days.map((d) => d['id']), next.days.map((d) => d['id']));

  final before = {for (final s in prev.scenarios) s['id']: s['manner']};
  for (final s in next.scenarios) {
    final m = before[s['id']];
    if (m != null && m != s['manner']) {
      out.add(Issue(true, '매너 바뀜: 시나리오 ${s['id']} $m → ${s['manner']}'));
    }
  }

  // ponytail: version을 뺀 필드를 jsonEncode로 비교한다. 키 순서만 바뀌어도 다르다고 보고,
  // 최상위 `$schema`(Content에 없음)는 보지 않는다.
  String body(Content c) => jsonEncode([c.schema, c.principles, c.manners, c.scenarios, c.days]);
  if (next.version < prev.version || (next.version == prev.version && body(prev) != body(next))) {
    out.add(Issue(true, 'version이 크지 않음: ${prev.version} → ${next.version}'));
  }
  return out;
}

/// `--sources`의 색인(`pipeline/sources/sources.json`, ADR 0009 §6)과 출처를 대조한다.
/// 글자 수는 코드 포인트(runes)로 센다. 한글은 UTF-16 길이와 같고, 이모지 같은 BMP 밖 글자도 1자다.
List<Issue> checkSources(Content c, List<Json> index) {
  final out = <Issue>[];
  for (final (i, e) in index.indexed) {
    for (final k in ['publisher', 'title', 'date', 'url', 'manners', 'summary']) {
      final v = e[k];
      if (v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty)) {
        out.add(Issue(true, '$k 없음: 색인 $i'));
      }
    }
    if (e['summary'] case String s when s.runes.length > 1000) {
      out.add(Issue(true, 'summary 1,000자 초과: 색인 $i (${s.runes.length}자)'));
    }
  }
  for (final s in c.scenarios) {
    for (final src in (((s['evidence'] as Json?)?['sources'] as List?) ?? const []).cast<Json>()) {
      final ok = index.any((e) =>
          ((e['manners'] as List?) ?? const []).contains(s['manner']) &&
          ['url', 'publisher', 'title', 'date'].every((k) => e[k] == src[k]));
      if (!ok) out.add(Issue(true, '색인과 맞지 않는 출처: ${s['id']} ${src['url']}'));
    }
  }
  return out;
}
