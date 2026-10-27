// 콘텐츠 검사 (ADR 0003 §6).
// 사용법: dart run tool/validate_content.dart assets/content.json [--previous=<이전 파일>]
// --previous가 없으면 파일 하나 검사만 한다.
// 문제를 한 줄씩 출력하고, 오류가 있으면 종료 코드 1, 경고만 있으면 0.
import 'dart:io';

import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/validate.dart';

void main(List<String> args) {
  Content load(String path) => parseContent(File(path).readAsStringSync());
  const flag = '--previous=';
  final next = load(args.where((a) => !a.startsWith(flag)).single);
  final issues = [
    ...validate(next),
    for (final a in args)
      if (a.startsWith(flag)) ...compare(load(a.substring(flag.length)), next),
  ];
  issues.forEach(stdout.writeln);
  exitCode = issues.any((i) => i.error) ? 1 : 0;
}
