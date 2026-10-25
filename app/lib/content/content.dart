// 콘텐츠 파일 파싱과 vary 펼치기 (ADR 0003). 순수 Dart: Flutter, 파일 입출력 없음.
import 'dart:convert';

typedef Json = Map<String, Object?>;

class Content {
  Content(this.schema, this.version, this.principles, this.manners, this.scenarios, this.days);
  final int schema, version;
  final List<Json> principles, manners, scenarios, days;

  /// 펼친 문제 id → 문제. 은퇴한 것도 들어 있다(조회용).
  late final Map<String, Json> questions = {
    for (final s in scenarios)
      for (final q in expand(s)) q['id'] as String: q,
  };
  late final Map<Object?, Json> _manners = {for (final m in manners) m['id']: m};

  /// 출제에 쓸 수 있는 펼친 문제. 은퇴한 매너·시나리오·보기에 걸린 것은 뺀다 (ADR 0003 §2).
  late final List<Json> selectable = [
    for (final q in questions.values)
      if (q['retired'] != true && _manners[q['manner']]?['retired'] != true) q,
  ];

  /// 기록의 id로 매너와 문제를 찾는다. 은퇴한 것도 찾는다.
  /// 펼친 문제가 콘텐츠에 없으면 `~` 앞의 기본 id로 매너만 찾는다(question null). 그래도 없으면 null.
  ({Json manner, Json? question})? lookup(String id) {
    final q = questions[id];
    final base = id.split('~').first;
    final m = _manners[q?['manner'] ?? scenarios.where((s) => s['id'] == base).firstOrNull?['manner']];
    return m == null ? null : (manner: m, question: q);
  }
}

Content parseContent(String source) {
  final j = jsonDecode(source) as Json;
  List<Json> list(String k) => (j[k] as List).cast<Json>();
  return Content(j['schema'] as int, j['version'] as int, list('principles'), list('manners'),
      list('scenarios'), list('days'));
}

/// 기본 시나리오 하나를 축 조합마다 펼친다. id는 `<기본 id>~<key>.<key>`(축 순서), vary가 없으면 기본 id.
/// 보기의 `area`, `feedback`이 기본값을 덮어쓰고, 보기들의 `vars`를 합쳐 `{변수}` 자리를 채운다.
/// 은퇴한 시나리오나 은퇴한 보기를 포함한 문제는 `retired: true`다.
List<Json> expand(Json base) {
  final vary = base['vary'] as List?;
  final rest = {...base}..remove('vary');
  if (vary == null) return [rest];

  var combos = [<Json>[]];
  for (final axis in vary.cast<List>()) {
    combos = [for (final c in combos) for (final o in axis.cast<Json>()) [...c, o]];
  }
  return [
    for (final opts in combos)
      () {
        final s = {...rest, 'id': '${base['id']}~${opts.map((o) => o['key']).join('.')}'};
        final vars = <String, Object?>{};
        for (final o in opts) {
          if (o['retired'] == true) s['retired'] = true;
          for (final k in const ['area', 'feedback']) {
            if (o.containsKey(k)) s[k] = o[k];
          }
          vars.addAll((o['vars'] as Map?)?.cast<String, Object?>() ?? const {});
        }
        s['vars'] = vars;
        return _fill(s, vars) as Json;
      }(),
  ];
}

final _slot = RegExp(r'\{(\w+)(와|과|은|는|이|가|을|를)?\}');
const _josaPairs = ['과와', '은는', '이가', '을를']; // [받침 있음, 없음]

Object? _fill(Object? v, Json vars) => switch (v) {
      String s => s.replaceAllMapped(_slot, (m) {
          final x = vars[m[1]];
          if (x == null) return m[0]!; // 모르는 자리는 그대로 둔다(검사기가 잡는다)
          return m[2] == null ? '$x' : _josa('$x', m[2]!);
        }),
      List l => [for (final x in l) _fill(x, vars)],
      Map m => <String, Object?>{for (final e in m.entries) e.key as String: _fill(e.value, vars)},
      _ => v,
    };

String _josa(String w, String j) {
  final c = w.isEmpty ? 0 : w.codeUnitAt(w.length - 1);
  final batchim = c >= 0xac00 && c <= 0xd7a3 && (c - 0xac00) % 28 != 0;
  return w + _josaPairs.firstWhere((p) => p.contains(j))[batchim ? 0 : 1];
}
