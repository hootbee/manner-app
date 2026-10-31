// 콘텐츠 생성·검토 파이프라인의 순수 함수 (ADR 0009 §9). main과 Messages API 호출은 A7·A8에서 더한다.
// 형식 이름과 장소 이름은 쓰지 않는다. 스키마와 templates.dart에서 읽는다(§4, 테스트가 확인한다).
import 'dart:convert';
import 'dart:math';

import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/templates.dart';

/// 블라인드 풀이용 문제 (§4). `blindHidden` 키를 어느 깊이에서든 지우고 `blindShuffled` 배열을 섞는다. 원본은 바뀌지 않는다.
Json blind(Json question, Random random) => _blind(question, random) as Json;

Object? _blind(Object? v, Random random) => switch (v) {
      Map m => <String, Object?>{
          for (final e in m.entries)
            if (!blindHidden.contains(e.key)) e.key as String: _blindValue(e.key, e.value, random),
        },
      List l => [for (final x in l) _blind(x, random)],
      _ => v,
    };

Object? _blindValue(Object? key, Object? v, Random random) {
  final out = _blind(v, random);
  if (out is List && blindShuffled.contains(key)) out.shuffle(random);
  return out;
}

/// 시나리오를 `scenarios` 끝에 붙이고 `version`을 1 올린 파일 텍스트 (§2).
/// `manner`는 파일의 `manners`에 같은 id가 없을 때만 붙는다. 기존 항목과 `days`는 고치지 않는다.
String addScenarios(String source, List<Json> scenarios, {Json? manner}) {
  final file = jsonDecode(source) as Json;
  final manners = file['manners'] as List;
  file['version'] = (file['version'] as int) + 1;
  if (manner != null && !manners.any((m) => (m as Map)['id'] == manner['id'])) manners.add(manner);
  (file['scenarios'] as List).addAll(scenarios);
  return '${const JsonEncoder.withIndent('  ').convert(file)}\n';
}

/// 열린 PR 목록(GitHub API 모양, `head.ref`)에 `content/` 브랜치가 있는가 (§3 1단계).
/// 모양이 다르면 거짓으로 넘기지 않고 예외를 낸다. 막는 검사가 조용히 꺼지지 않게 한다.
bool openPipelinePr(List<Json> pulls) => pulls.any((p) {
      final ref = (p['head'] as Map?)?['ref'];
      if (ref is! String) throw FormatException('PR에 head.ref가 없다: $p');
      return ref.startsWith('content/');
    });

/// PR 본문 (§11). `hasSources`가 거짓이면 첫 줄이 "근거 문서 없음"이다.
String prBody({
  required bool hasSources,
  required int manner,
  required String mannerName,
  required int scenarioCount,
  required int questionCount,
  required int fromVersion,
  required bool newManner,
  required String runUrl,
  required List<Json> flags,
  required List<Json> questions,
  required String model,
  required String sha,
  required String usage,
  required String validate,
}) {
  String cell(Object? s) => '$s'.replaceAll(RegExp(r'\s*\n\s*'), ' ').replaceAll('|', r'\|');
  final flagTable = flags.isEmpty
      ? '없음'
      : [
          '| 문제 | 종류 | 메모 |',
          '| --- | --- | --- |',
          for (final f in flags) '| `${f['id']}` | ${cell(f['kind'])} | ${cell(f['note'])} |',
        ].join('\n');
  return [
    if (!hasSources) '근거 문서 없음\n',
    '## 무엇을',
    '매너 $manner "$mannerName"에 기본 시나리오 $scenarioCount개(펼친 문제 $questionCount개)를 더한다. '
        'content version $fromVersion → ${fromVersion + 1}.${newManner ? ' 매너 항목도 더한다.' : ''}\n',
    '## 왜',
    'ADR 0009 파이프라인 실행 $runUrl\n',
    '## 검토 표시 (Claude. 막지 않는다)',
    '$flagTable\n',
    '## 새 문제 (자리 표시를 채운 지문)',
    for (final q in questions) '- `${q['id']}`: ${cell(q['prompt'])}',
    '',
    '## 어떻게 확인했나',
    '- 코드 검사: $validate',
    '- 모델 $model · 커밋 $sha · 호출별 토큰(입력/캐시 쓰기/캐시 읽기/출력) $usage\n',
    '## 사람이 확인할 것',
    '- [ ] 새 문제를 모두 읽었다(지문, 정답, 해설). 매너 항목이 붙었으면 기획서 표와 같다',
    '- [ ] 검토 표시를 하나씩 처리했다(고쳤거나, 괜찮은 이유를 댓글로 남겼다). `형식` 표시는 #26에 옮겼다',
    '- [ ] 첫 줄이 "근거 문서 없음"이고 의전 매너(4·5·6·30)이면, ADR 0009 "근거가 불명확한 매너" 표에 그 매너가 있다',
    '- [ ] content CI가 통과했다',
    '',
  ].join('\n');
}
