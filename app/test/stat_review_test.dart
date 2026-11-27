import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/screens/manner_stats_screen.dart';
import 'package:mannerfit/screens/my_page_screen.dart';
import 'package:mannerfit/screens/partner_artwork.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/stat_share_screen.dart';

void main() {
  setUp(() => backend = FakeBackend());

  for (final preview in [false, true]) {
    for (final label in ['나의 매너 스탯', '스탯 공유']) {
      testWidgets('$label receives preview=$preview from profile', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MyPageScreen(partner: MannerPartner.cat, preview: preview),
          ),
        );
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (label == '나의 매너 스탯') {
          expect(
            tester
                .widget<MannerStatsScreen>(find.byType(MannerStatsScreen))
                .preview,
            preview,
          );
        } else {
          expect(
            tester
                .widget<StatShareScreen>(find.byType(StatShareScreen))
                .preview,
            preview,
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }

  for (final partner in MannerPartner.values) {
    testWidgets('card shows only ${partner.name} and scores in points', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatShareCard(
                home: backend.home.value,
                stats: const [AreaStat('대화', 80)],
                partner: partner,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PartnerArtwork), findsOneWidget);
      expect(
        tester.widget<PartnerArtwork>(find.byType(PartnerArtwork)).partner,
        partner,
      );
      expect(find.text('80점'), findsOneWidget);
      expect(find.text('80%'), findsNothing);
      expect(find.text('미리보기 · 샘플 학습 데이터'), findsNothing);
    });
  }
}
