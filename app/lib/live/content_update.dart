// ADR 0003 §5 앱 시작 순서 1~4: 저장된 콘텐츠 고르기(시작 때, 동기)와 새 콘텐츠 받아 두기(백그라운드).
// 받은 콘텐츠는 다음 시작의 pickContent부터 쓴다(§5-4). 앱이 읽는 schema는 번들의 schema다.
import 'dart:convert';
import 'dart:io';

import '../auth/offline.dart';
import '../content/content.dart';
import '../content/validate.dart';

/// §5-1. `dir/content.json`이 읽히고 schema가 번들과 같고 version이 번들보다 크면 그것, 아니면 번들을 쓰고 저장 파일을 지운다.
Content pickContent(Directory dir, Content bundled, {required void Function(Object, StackTrace) report}) {
  final file = File('${dir.path}/content.json');
  try {
    final saved = parseContent(file.readAsStringSync());
    if (saved.schema == bundled.schema && saved.version > bundled.version) return saved;
  } on PathNotFoundException catch (_) {
    // 첫 실행이거나 받은 적 없음. 실패가 아니다.
  } catch (e, s) {
    report(e, s); // 깨진 파일은 보내고 번들로 간다(ADR 0007 §3)
  }
  try {
    file.deleteSync();
  } on FileSystemException catch (_) {
    // 없는 파일. 지우지 못해도 다음 시작 때 같은 이유로 다시 번들을 쓴다.
  }
  return bundled;
}

/// §5-2~3. manifest를 받아(5초) version이 [current]보다 크면 본문을 받아 검사하고 `dir/content.json`으로 바꾼다.
/// 어떤 실패든 아무것도 바꾸지 않고 예외 없이 끝난다(다음 시작 때 다시 한다). 진행 중에 다시 부르면 같은 Future를 돌려준다.
Future<void> fetchContent(String supabaseUrl, Directory dir, Content current,
        {required void Function(Object, StackTrace) report, Future<String> Function(Uri) get = httpGet}) =>
    _running ??= _fetch(supabaseUrl, dir, current, get, report).whenComplete(() => _running = null);

Future<void>? _running;

Future<void> _fetch(String supabaseUrl, Directory dir, Content current, Future<String> Function(Uri) get,
    void Function(Object, StackTrace) report) async {
  try {
    final folder = '$supabaseUrl/storage/v1/object/public/content/s${current.schema}';
    final manifest = jsonDecode(await get(Uri.parse('$folder/manifest.json')).timeout(const Duration(seconds: 5)));
    final version = manifest['version'] as int;
    if (version <= current.version) return;

    final body = await get(Uri.parse('$folder/$version.json'));
    final next = parseContent(body);
    if (next.schema != current.schema || next.version != version || validate(next).any((i) => i.error)) {
      throw StateError('content invalid'); // 아래 catch로 보낸다
    }

    // tmp에 전부 쓰고 rename. 중간에 죽어도 옛 파일이나 새 파일 하나가 온전히 남는다.
    File('${dir.path}/content.json.tmp')
      ..writeAsStringSync(body, flush: true)
      ..renameSync('${dir.path}/content.json');
  } catch (e, s) {
    // 네트워크 없음, 비-200, 깨진 JSON, 검사 실패, 디스크 오류. 학습은 지금 콘텐츠로 그대로 간다.
    if (!isOffline(e)) report(e, s); // ADR 0007 §3
    try {
      File('${dir.path}/content.json.tmp').deleteSync(); // 쓰기나 rename이 실패해 남은 tmp
    } on FileSystemException catch (_) {
      // 없는 파일
    }
  }
}

/// 실제 가져오기. 200이 아니면 Exception('HTTP …'). HttpException은 응답 도중 끊김(전송 오류)이라 쓰지 않는다(ADR 0007 §2).
Future<String> httpGet(Uri uri) async {
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(uri)).close();
    if (res.statusCode != HttpStatus.ok) throw Exception('HTTP ${res.statusCode} $uri');
    return await res.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}
