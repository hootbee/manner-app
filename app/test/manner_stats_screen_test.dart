import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/screens/manner_stats_screen.dart';

void main() {
  testWidgets('stats react to backend values and area filter', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stats = ValueNotifier<List<AreaStat>>([
      for (final area in ['대화', '식사', '공공장소', '대중교통', '학교·직장', '디지털'])
        AreaStat(area, 0),
    ]);
    addTearDown(stats.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MannerStatsScreen(stats: stats),
      ),
    );
    expect(
      find.bySemanticsLabel(
        '매너 스탯: 대화 0%, 식사 0%, 공공장소 0%, 대중교통 0%, 학교·직장 0%, 디지털 0%',
      ),
      findsOneWidget,
    );
    stats.value = [for (final s in stats.value) AreaStat(s.area, 100)];
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    await tester.tap(find.text('식사').first);
    await tester.pumpAndSettle();
    expect(find.text('식사 분야'), findsOneWidget);
    await tester.ensureVisible(find.text('매너 파트너의 한마디'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty records do not invent percentages; small screen scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stats = ValueNotifier<List<AreaStat>>([]);
    addTearDown(stats.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MannerStatsScreen(stats: stats),
      ),
    );
    expect(find.text('아직 표시할 학습 스탯이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
