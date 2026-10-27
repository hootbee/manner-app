// ADR 0005: 기기 안 기록 저장소(records.json 하나)와 ADR 0001 §3 동기화.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../engine/engine.dart';

const tables = ['attempts', 'day_completions'];

/// 새 기록 id. UUID v4를 Random.secure()로 만든다(uuid 패키지 안 씀).
String newId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = b[6] & 0x0f | 0x40; // version 4
  b[8] = b[8] & 0x3f | 0x80; // variant 10
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// 행 = 서버 insert 권한이 있는 컬럼 + `synced`. 커서는 `cursors[table]`.
class Store {
  /// 파일이 없으면 빈 저장소다. 읽지 못하면 예외를 던진다.
  Store(this._file, this._client)
      : _data = _file.existsSync() ? jsonDecode(_file.readAsStringSync()) as Map<String, dynamic> : {};

  final File _file;
  final SupabaseClient _client;
  final Map<String, dynamic> _data;

  /// 엔진에 넘길 집합. 순서는 의미 없다.
  List<Attempt> get attempts => [
        for (final r in _rows('attempts'))
          Attempt(id: r['id'], scenarioId: r['scenario_id'], grade: Grade.values.byName(r['grade']), solvedOn: DateTime.parse(r['solved_on'])),
      ];

  List<DayCompletion> get dayCompletions => [
        for (final r in _rows('day_completions'))
          DayCompletion(id: r['id'], dayId: r['day_id'], completedOn: DateTime.parse(r['completed_on'])),
      ];

  /// 모든 테이블의 synced=false 행 수. 로그아웃 확인의 N.
  int get unsynced => tables.fold(0, (n, t) => n + _rows(t).where((r) => r['synced'] == false).length);

  /// synced=false로 파일에 쓰고 돌아온다. 이미 있는 id면 아무것도 안 한다.
  void addAttempt(Attempt a) =>
      _add('attempts', {'id': a.id, 'scenario_id': a.scenarioId, 'grade': a.grade.name, 'solved_on': _date(a.solvedOn)});

  void addDayCompletion(DayCompletion d) =>
      _add('day_completions', {'id': d.id, 'day_id': d.dayId, 'completed_on': _date(d.completedOn)});

  /// ADR 0001 §3의 push 뒤 pull. 로그인 전이면 바로 끝난다. 오류는 그대로 던진다.
  Future<void> sync(String table) => _inLine(() => _sync(table));

  /// 앞선 sync가 끝나면 파일과 메모리를 지우고 signOut(local).
  Future<void> clear() => _inLine(() async {
        _data.clear();
        if (_file.existsSync()) _file.deleteSync();
        try {
          await _client.auth.signOut(scope: SignOutScope.local); // 기기 세션은 요청 전에 지워진다
        } catch (_) {
          // 서버 알림 실패는 무시한다(ADR 0005 §4).
        }
      });

  /// sync와 clear는 한 줄로 서서 차례로 돈다. 앞의 실패는 뒤를 막지 않는다.
  Future<void> _last = Future.value();
  Future<void> _inLine(Future<void> Function() f) {
    final run = _last.then((_) => f());
    _last = run.catchError((_) {});
    return run;
  }

  Future<void> _sync(String table) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final rows = _rows(table);

    // push: synced=false 행을 500개씩. 서버는 같은 id를 무시한다.
    for (;;) {
      final batch = rows.where((r) => r['synced'] == false).take(500).toList();
      if (batch.isEmpty) break;
      await _client
          .from(table)
          .upsert([for (final r in batch) Map.of(r)..remove('synced')], onConflict: 'id', ignoreDuplicates: true);
      for (final r in batch) {
        r['synced'] = true;
      }
      _save();
    }

    // pull: (created_at, id) 키셋으로 1000행씩. 커서가 있으면 5분 앞에서 시작한다.
    final cursors = (_data['cursors'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    final cursor = cursors[table] as Map<String, dynamic>?;
    String? c = cursor == null ? null : _utc(DateTime.parse(cursor['created_at']).subtract(const Duration(minutes: 5)));
    String i = '00000000-0000-0000-0000-000000000000';
    for (;;) {
      var q = _client.from(table).select().eq('user_id', user.id);
      if (c != null) q = q.or('created_at.gt.$c,and(created_at.eq.$c,id.gt.$i)');
      final page = await q.order('created_at', ascending: true).order('id', ascending: true).limit(1000);
      if (page.isEmpty) break;
      final ids = {for (final r in rows) r['id']};
      for (final r in page) {
        if (!ids.contains(r['id'])) rows.add({...r, 'synced': true}..remove('user_id')..remove('created_at'));
      }
      c = _utc(DateTime.parse(page.last['created_at']));
      i = page.last['id'];
      cursors[table] = {'created_at': c, 'id': i};
      _save();
      if (page.length < 1000) break;
    }
  }

  List<Map<String, dynamic>> _rows(String table) => (_data[table] ??= <dynamic>[]).cast<Map<String, dynamic>>();

  void _add(String table, Map<String, dynamic> row) {
    final rows = _rows(table);
    if (rows.any((r) => r['id'] == row['id'])) return;
    rows.add({...row, 'synced': false});
    _save();
  }

  /// tmp에 전부 쓰고 rename. 앱이 중간에 죽어도 옛 파일이나 새 파일 하나가 온전히 남는다.
  void _save() {
    File('${_file.path}.tmp')
      ..writeAsStringSync(jsonEncode(_data), flush: true)
      ..renameSync(_file.path);
  }
}

String _date(DateTime t) => day(t).toIso8601String().substring(0, 10);

/// `Z` 형식 UTC 시각. `+00:00`은 URL에서 `+`가 공백이 되어 실패한다.
String _utc(DateTime t) => t.toUtc().toIso8601String();
