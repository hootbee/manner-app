// 콘텐츠 파일 하나 검사 (ADR 0003 §6). 사용법: dart run tool/validate_content.dart assets/content.json
// 문제를 한 줄씩 출력하고, 오류가 있으면 종료 코드 1, 경고만 있으면 0.
import 'dart:io';

import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/content/validate.dart';

void main(List<String> args) {
  final issues = validate(parseContent(File(args.single).readAsStringSync()));
  issues.forEach(stdout.writeln);
  exitCode = issues.any((i) => i.error) ? 1 : 0;
}
