// ADR 0005 §5: Supabase 없이 늘 도는 저장소 테스트.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/engine/engine.dart';
import 'package:mannerfit/sync/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('newId() 1,000개는 모두 UUID v4 형식이고 서로 다르다', () {
    final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = List.generate(1000, (_) => newId());
    expect(ids.where((id) => !v4.hasMatch(id)), isEmpty);
    expect(ids.toSet(), hasLength(1000));
  });

  late Directory dir;
  late File file;
  // 닿지 않는 주소. 요청을 보내면 예외가 난다.
  final offline = SupabaseClient('http://127.0.0.1:1', 'x');
  final a = Attempt(id: newId(), scenarioId: 'A-sidewalk~partner.right', grade: Grade.ok, solvedOn: DateTime(2026, 10, 27, 23, 59));
  final d = DayCompletion(id: newId(), dayId: 'day-01', completedOn: DateTime(2026, 10, 26, 8));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('store_test');
    file = File('${dir.path}/records.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('파일이 없으면 빈 저장소다', () {
    final s = Store(file, offline);
    expect(s.attempts, isEmpty);
    expect(s.dayCompletions, isEmpty);
    expect(s.unsynced, 0);
  });

  test('같은 id로 addAttempt를 두 번 하면 attempts 1개, unsynced 1', () {
    final s = Store(file, offline);
    s.addAttempt(a);
    s.addAttempt(Attempt(id: a.id, scenarioId: 'other', grade: Grade.best, solvedOn: DateTime(2026, 11, 1)));
    expect(s.attempts, hasLength(1));
    expect(s.attempts.single.scenarioId, a.scenarioId);
    expect(s.unsynced, 1);
  });

  test('같은 id로 addDayCompletion을 두 번 하면 1개', () {
    final s = Store(file, offline);
    s.addDayCompletion(d);
    s.addDayCompletion(d);
    expect(s.dayCompletions, hasLength(1));
    expect(s.unsynced, 1);
  });

  test('같은 파일로 새 Store를 열면 같은 기록이 나온다(날짜는 연월일만)', () {
    Store(file, offline)
      ..addAttempt(a)
      ..addDayCompletion(d);
    final s = Store(file, offline);
    final got = s.attempts.single;
    expect([got.id, got.scenarioId, got.grade, day(got.solvedOn)], [a.id, a.scenarioId, a.grade, DateTime.utc(2026, 10, 27)]);
    final gotD = s.dayCompletions.single;
    expect([gotD.id, gotD.dayId, day(gotD.completedOn)], [d.id, d.dayId, DateTime.utc(2026, 10, 26)]);
    expect(s.unsynced, 2);
  });

  test('records.json.tmp가 남아 있어도 records.json을 읽는다', () {
    Store(file, offline).addAttempt(a);
    File('${file.path}.tmp').writeAsStringSync('{"attempts": [{"id": "반쯤 쓰다 죽음');
    final s = Store(file, offline);
    expect(s.attempts.single.id, a.id);
  });

  test('records.json을 읽지 못하면 예외를 던진다(지우고 새로 시작하지 않는다)', () {
    file.writeAsStringSync('{"attempts": [');
    expect(() => Store(file, offline), throwsA(isA<FormatException>()));
    expect(file.readAsStringSync(), '{"attempts": [');
  });

  test('로그인 전 sync는 요청 없이 끝나고 unsynced가 그대로다', () async {
    final s = Store(file, offline)..addAttempt(a);
    await s.sync('attempts');
    expect(s.unsynced, 1);
  });
}
