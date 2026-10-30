// 콘텐츠 검사 (ADR 0003 §6).
// 사용법: dart run tool/validate_content.dart assets/content.json [--previous=<이전 파일>] [--sources=<색인 파일>]
// --previous가 없으면 파일 하나 검사만 한다. --sources가 있으면 출처를 색인과 대조한다(ADR 0009 §6).
// 문제를 한 줄씩 출력하고, 오류가 있으면 종료 코드 1, 경고만 있으면 0.
import 'dart:convert';
import 'dart:io';

import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/validate.dart';

void main(List<String> args) {
  Content load(String path) => parseContent(File(path).readAsStringSync());
  const flag = '--previous=', sources = '--sources=';
  // 오타 플래그를 조용히 무시하면 대조 없이 0으로 끝난다.
  for (final a in args) {
    if (a.startsWith('--') && !a.startsWith(flag) && !a.startsWith(sources)) {
      stderr.writeln('모르는 플래그: $a');
      exitCode = 1;
      return;
    }
  }
  final next = load(args.where((a) => !a.startsWith('--')).single);
  final issues = [
    ...validate(next),
    for (final a in args)
      if (a.startsWith(flag))
        ...compare(load(a.substring(flag.length)), next)
      else if (a.startsWith(sources))
        ...checkSources(next, (jsonDecode(File(a.substring(sources.length)).readAsStringSync()) as List).cast<Json>()),
  ];
  issues.forEach(stdout.writeln);
  exitCode = issues.any((i) => i.error) ? 1 : 0;
}
