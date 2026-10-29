import 'package:flutter_test/flutter_test.dart';

import 'package:mannerfit/main.dart';

// ADR 0007 §1 "스택은 앞 50줄만 보낸다"
void main() {
  StackTrace stackOf(int n) => StackTrace.fromString(
      List.generate(n, (i) => '#$i f (package:mannerfit/x.dart:1)').join('\n'));

  test('812줄 스택은 앞 50줄만 남고 첫 줄이 같다', () {
    final lines = trimStack(stackOf(812)).toString().split('\n');
    expect(lines.length, 50);
    expect(lines.first, '#0 f (package:mannerfit/x.dart:1)');
  });

  test('50줄 이하 스택은 그대로다', () {
    final s = stackOf(3);
    expect(trimStack(s).toString(), s.toString());
  });

  test('null과 빈 스택은 비지 않은 50줄 이하 스택이 된다', () {
    for (final s in [null, StackTrace.empty]) {
      final text = trimStack(s).toString();
      expect(text, isNotEmpty);
      expect(text.split('\n').length, lessThanOrEqualTo(50));
    }
  });

  test('null이면 깊은 지금 스택도 50줄로 자른다', () {
    StackTrace deep(int n) => n == 0 ? trimStack(null) : deep(n - 1);
    expect(trimStack(null).toString().split('\n').length, lessThan(50)); // 얕은 곳은 그대로
    expect(deep(60).toString().split('\n').length, 50);
  });
}
