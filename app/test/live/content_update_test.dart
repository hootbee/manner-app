// ADR 0003 §5 앱 시작 순서 1~4: 저장된 콘텐츠 고르기와 새 콘텐츠 받아 두기. 네트워크는 가짜 함수다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/live/content_update.dart';

void main() {
  final bundleJson = File('assets/content.json').readAsStringSync();
  final bundle = parseContent(bundleJson); // schema 1, version 1

  /// 번들을 고친 콘텐츠 JSON.
  String variant({int? schema, int? version, void Function(Map<String, dynamic>)? edit}) {
    final j = jsonDecode(bundleJson) as Map<String, dynamic>;
    if (schema != null) j['schema'] = schema;
    if (version != null) j['version'] = version;
    edit?.call(j);
    return jsonEncode(j);
  }

  const url = 'https://example.test';
  final manifestUri = Uri.parse('$url/storage/v1/object/public/content/s1/manifest.json');
  Uri bodyUri(int v) => Uri.parse('$url/storage/v1/object/public/content/s1/$v.json');

  late Directory dir;
  late File saved;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('content_update_test');
    saved = File('${dir.path}/content.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// 경로별 응답을 주고 받은 요청을 적는 가짜 HTTP. 없는 경로는 예외.
  late List<Uri> requested;
  Future<String> Function(Uri) fake(Map<Uri, String> responses) {
    requested = [];
    return (uri) async {
      requested.add(uri);
      final r = responses[uri];
      if (r == null) throw const SocketException('없음');
      return r;
    };
  }

  group('pickContent (§5-1)', () {
    test('저장된 파일이 없으면 번들을 쓴다', () {
      expect(pickContent(dir, bundle), same(bundle));
    });

    test('저장된 파일의 schema가 2면 번들을 쓰고 저장 파일을 지운다', () {
      saved.writeAsStringSync(variant(schema: 2, version: 5));
      expect(pickContent(dir, bundle), same(bundle));
      expect(saved.existsSync(), isFalse);
    });

    test('저장된 파일의 version이 번들 이하이면 번들을 쓰고 저장 파일을 지운다', () {
      saved.writeAsStringSync(variant(version: 1));
      expect(pickContent(dir, bundle), same(bundle));
      expect(saved.existsSync(), isFalse);
    });

    test('저장된 파일이 깨졌으면 번들을 쓰고 저장 파일을 지운다', () {
      saved.writeAsStringSync('{"schema": 1, "vers');
      expect(pickContent(dir, bundle), same(bundle));
      expect(saved.existsSync(), isFalse);
    });

    test('schema가 같고 version이 번들보다 크면 저장된 파일을 쓴다', () {
      saved.writeAsStringSync(variant(version: 2));
      expect(pickContent(dir, bundle).version, 2);
      expect(saved.existsSync(), isTrue);
    });
  });

  group('fetchContent (§5-2~4)', () {
    // 지금 쓰는 콘텐츠는 저장된 version 2다.
    late String current;
    setUp(() {
      current = variant(version: 2);
      saved.writeAsStringSync(current);
    });
    void expectUnchanged() {
      expect(saved.readAsStringSync(), current);
      expect(dir.listSync().map((e) => e.path), [saved.path]); // 임시 파일도 남지 않는다
    }

    final rejected = {
      '깨진 JSON': '{"schema": 1, "vers',
      'version이 manifest와 다름': variant(version: 4),
      'schema가 2': variant(schema: 2, version: 3),
      'validate 오류(장면이 없는 매너 99)': variant(
        version: 3,
        edit: (j) => ((j['days'] as List).first['scenes'] as List).first['manner'] = 99,
      ),
    };
    for (final MapEntry(key: why, value: body) in rejected.entries) {
      test('본문이 $why이면 저장된 파일이 그대로다', () async {
        final get = fake({manifestUri: '{"version": 3}', bodyUri(3): body});
        await fetchContent(url, dir, parseContent(current), get: get);
        expect(requested, [manifestUri, bodyUri(3)]);
        expectUnchanged();
      });
    }

    test('manifest version이 지금 것과 같으면 본문을 요청하지 않는다', () async {
      final get = fake({manifestUri: '{"version": 2}', bodyUri(2): current});
      await fetchContent(url, dir, parseContent(current), get: get);
      expect(requested, [manifestUri]);
      expectUnchanged();
    });

    test('manifest version이 지금 것보다 작으면 본문을 요청하지 않는다', () async {
      final get = fake({manifestUri: '{"version": 1}', bodyUri(1): bundleJson});
      await fetchContent(url, dir, parseContent(current), get: get);
      expect(requested, [manifestUri]);
      expectUnchanged();
    });

    test('네트워크가 없으면 예외 없이 끝나고 아무것도 바뀌지 않는다', () async {
      final get = fake({});
      await fetchContent(url, dir, parseContent(current), get: get);
      expect(requested, [manifestUri]);
      expectUnchanged();
    });

    test('새 version이 검사를 통과하면 저장 파일을 바꾸고 다음 pickContent가 그것을 고른다', () async {
      final next = variant(version: 3);
      final get = fake({manifestUri: '{"version": 3}', bodyUri(3): next});
      await fetchContent(url, dir, parseContent(current), get: get);
      expect(saved.readAsStringSync(), next);
      expect(dir.listSync().map((e) => e.path), [saved.path]); // 임시 파일은 rename되어 남지 않는다
      expect(pickContent(dir, bundle).version, 3);
    });

    test('동시에 두 번 불러도 요청은 한 번이다', () async {
      final get = fake({manifestUri: '{"version": 3}', bodyUri(3): variant(version: 3)});
      await Future.wait([
        fetchContent(url, dir, parseContent(current), get: get),
        fetchContent(url, dir, parseContent(current), get: get),
      ]);
      expect(requested, [manifestUri, bodyUri(3)]);
    });
  });

  group('httpGet', () {
    late HttpServer server;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        final ok = req.uri.path == '/ok';
        req.response
          ..statusCode = ok ? 200 : 400
          ..headers.contentType = ContentType.json
          ..write(ok ? '{"title": "인도 안쪽"}' : '{"error": "not_found"}')
          ..close();
      });
    });
    tearDown(() => server.close(force: true));
    Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

    test('200이면 본문을 UTF-8로 돌려준다', () async {
      expect(await httpGet(at('/ok')), '{"title": "인도 안쪽"}');
    });

    test('200이 아니면 예외를 던진다', () async {
      await expectLater(httpGet(at('/missing')), throwsA(isA<HttpException>()));
    });
  });
}
