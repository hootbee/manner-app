// ADR 0005 §5: 로컬 Supabase에 직접 붙는 동기화 테스트.
// 환경 변수 SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY가 없으면 skip한다(CLAUDE.md 검증 명령).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/engine/engine.dart';
import 'package:mannerfit/sync/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final env = Platform.environment;
final url = env['SUPABASE_URL'];
final anonKey = env['SUPABASE_ANON_KEY'];
final serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'];
const opts = AuthClientOptions(autoRefreshToken: false); // 테스트가 끝나도 타이머가 남지 않게

void main() {
  final skip = [url, anonKey, serviceKey].contains(null) ? 'Supabase 환경 변수 없음' : null;

  group('로컬 Supabase', skip: skip, () {
    late SupabaseClient admin;
    late Directory dir;
    final created = <String>[];
    final clients = <SupabaseClient>[];

    setUpAll(() => admin = SupabaseClient(url!, serviceKey!, authOptions: opts));
    setUp(() => dir = Directory.systemTemp.createTempSync('sync_test'));
    tearDown(() async {
      dir.deleteSync(recursive: true);
      for (final c in clients) {
        await c.dispose();
      }
      clients.clear();
    });
    tearDownAll(() async {
      for (final id in created) {
        try {
          await admin.auth.admin.deleteUser(id);
        } on AuthException catch (e) {
          if (e.statusCode != '404') rethrow; // 테스트가 이미 지운 사용자
        }
      }
      await admin.dispose();
    });

    // 이메일 로그인은 꺼져 있으므로(config.toml) admin이 만든 magic link의 hashed_token으로 로그인한다.
    Future<SupabaseClient> signIn(String email) async {
      final link = await admin.auth.admin.generateLink(type: GenerateLinkType.magiclink, email: email);
      final client = SupabaseClient(url!, anonKey!, authOptions: opts);
      clients.add(client);
      await client.auth.verifyOTP(tokenHash: link.properties.hashedToken, type: OtpType.magiclink);
      return client;
    }

    Future<(String, String)> newUser() async {
      final email = '${newId()}@test.local';
      final res = await admin.auth.admin.createUser(AdminUserAttributes(email: email, emailConfirm: true));
      created.add(res.user!.id);
      return (res.user!.id, email);
    }

    Future<int> serverCount(String table, String uid) async =>
        (await admin.from(table).select('id').eq('user_id', uid).count(CountOption.exact)).count;

    Attempt attempt() => Attempt(id: newId(), scenarioId: 'A-sidewalk~partner.right', grade: Grade.best, solvedOn: DateTime(2026, 10, 27));

    test('push: 501행을 sync 한 번에 올린다(500개씩)', () async {
      final (uid, email) = await newUser();
      final s = Store(File('${dir.path}/records.json'), await signIn(email));
      for (var i = 0; i < 501; i++) {
        s.addAttempt(attempt());
      }
      await s.sync('attempts');
      expect(await serverCount('attempts', uid), 501);
      expect(s.unsynced, 0);
    });

    test('같은 요청 두 번: 복사한 파일로 다시 sync해도 오류 없이 서버 1행', () async {
      final (uid, email) = await newUser();
      final client = await signIn(email);
      final file = File('${dir.path}/records.json');
      final s = Store(file, client)..addAttempt(attempt());
      final copy = file.copySync('${dir.path}/copy.json');
      await s.sync('attempts');
      final again = Store(copy, client);
      await again.sync('attempts');
      expect(await serverCount('attempts', uid), 1);
      expect(again.unsynced, 0);
    });

    Map<String, dynamic> serverAttempt(String uid, [String? createdAt]) => {
          'id': newId(),
          'user_id': uid,
          'scenario_id': 'A-sidewalk~partner.right',
          'grade': 'ok',
          'solved_on': '2026-10-27',
          'created_at': ?createdAt,
        };

    test('pull: 서버의 1,001행을 sync 한 번에 받는다(1,000개씩)', () async {
      final (uid, email) = await newUser();
      await admin.from('attempts').insert([for (var i = 0; i < 1001; i++) serverAttempt(uid)]);
      final s = Store(File('${dir.path}/records.json'), await signIn(email));
      await s.sync('attempts');
      expect(s.attempts, hasLength(1001));
      expect(s.unsynced, 0);
    });

    test('pull: 커서보다 1분 앞선 created_at으로 늦게 들어온 행도 다음 sync에서 받는다(5분 겹침)', () async {
      final (uid, email) = await newUser();
      await admin.from('attempts').insert(serverAttempt(uid));
      final file = File('${dir.path}/records.json');
      final s = Store(file, await signIn(email));
      await s.sync('attempts');
      final cursor = (jsonDecode(file.readAsStringSync())['cursors']['attempts']['created_at']) as String;
      final late = serverAttempt(uid, DateTime.parse(cursor).subtract(const Duration(minutes: 1)).toUtc().toIso8601String());
      await admin.from('attempts').insert(late);
      await s.sync('attempts');
      expect(s.attempts.map((a) => a.id), contains(late['id']));
      expect(s.attempts, hasLength(2));
    });

    test('기기 두 대: A·B·A 순서로 sync하면 두 저장소의 id 집합이 같다', () async {
      final (_, email) = await newUser();
      final a = Store(File('${dir.path}/a.json'), await signIn(email));
      final b = Store(File('${dir.path}/b.json'), await signIn(email));
      a
        ..addAttempt(attempt())
        ..addDayCompletion(DayCompletion(id: newId(), dayId: 'day-01', completedOn: DateTime(2026, 10, 26)));
      b
        ..addAttempt(attempt())
        ..addDayCompletion(DayCompletion(id: newId(), dayId: 'day-02', completedOn: DateTime(2026, 10, 27)));
      for (final s in [a, b, a]) {
        for (final t in tables) {
          await s.sync(t);
        }
      }
      expect(a.attempts.map((x) => x.id).toSet(), b.attempts.map((x) => x.id).toSet());
      expect(a.attempts, hasLength(2));
      expect(a.dayCompletions.map((x) => x.id).toSet(), b.dayCompletions.map((x) => x.id).toSet());
      expect(a.dayCompletions, hasLength(2));
    });

    test('네트워크 없음: sync는 예외를 던지고 unsynced와 파일이 그대로이고, 그 뒤 addAttempt가 된다', () async {
      final (_, email) = await newUser();
      final online = await signIn(email);
      // 만료 전 세션이면 recoverSession은 네트워크를 쓰지 않는다(gotrue 2.27.3).
      final offline = SupabaseClient('http://127.0.0.1:1', anonKey!, authOptions: opts);
      clients.add(offline);
      await offline.auth.recoverSession(jsonEncode(online.auth.currentSession));
      expect(offline.auth.currentUser, isNotNull);

      final file = File('${dir.path}/records.json');
      final s = Store(file, offline)..addAttempt(attempt());
      final before = file.readAsStringSync();
      await expectLater(s.sync('attempts'), throwsA(isA<Exception>()));
      expect(s.unsynced, 1);
      expect(file.readAsStringSync(), before);
      s.addAttempt(attempt());
      expect(s.attempts, hasLength(2));
      expect(s.unsynced, 2);
    });

    test('clear: sync를 기다리지 않고 clear를 불러도 지운 뒤 다시 받아 오지 않는다', () async {
      final (uid, email) = await newUser();
      await admin.from('attempts').insert(serverAttempt(uid));
      final client = await signIn(email);
      final file = File('${dir.path}/records.json');
      final s = Store(file, client)..addAttempt(attempt());
      await Future.wait([s.sync('attempts'), s.clear()]);
      expect(file.existsSync(), isFalse);
      expect(s.attempts, isEmpty);
      expect(client.auth.currentUser, isNull);
      await s.sync('attempts');
      expect(file.existsSync(), isFalse);
    });

    test('다른 기기에서 탈퇴: 사용자가 지워진 뒤 남은 행을 sync하면 PostgrestException 23503', () async {
      final (uid, email) = await newUser();
      final s = Store(File('${dir.path}/records.json'), await signIn(email))..addAttempt(attempt());
      await admin.auth.admin.deleteUser(uid);
      await expectLater(s.sync('attempts'), throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23503')));
    });
  });
}
