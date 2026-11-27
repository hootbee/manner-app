import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/screens/my_page_screen.dart';
import 'package:mannerfit/screens/partner_artwork.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/stat_share_screen.dart';

void main() {
  setUp(() => backend = FakeBackend());
  for (final preview in [false, true]) {
    testWidgets('profile passes explicit preview=$preview to sharing', (
      t,
    ) async {
      t.view.physicalSize = const Size(393, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MyPageScreen(partner: MannerPartner.monkey, preview: preview),
        ),
      );
      final menu = find.text('스탯 공유');
        await Scrollable.ensureVisible(t.element(menu), alignment: 0.3);
        await t.pumpAndSettle();
      await t.tap(menu);
      await t.pumpAndSettle();
      expect(
        t.widget<StatShareScreen>(find.byType(StatShareScreen)).preview,
        preview,
      );
      expect(
        t.widget<StatShareScreen>(find.byType(StatShareScreen)).partner,
        MannerPartner.monkey,
      );
    });
  }
  testWidgets(
    'share card uses selected partner and scores without percentages',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatShareCard(
                home: backend.home.value,
                stats: backend.stats.value,
                partner: MannerPartner.cat,
              ),
            ),
          ),
        ),
      );
      final art = find.byType(PartnerArtwork);
      expect(art, findsOneWidget);
      expect(t.widget<PartnerArtwork>(art).partner, MannerPartner.cat);
      for (final stat in backend.stats.value) {
        expect(find.text('${stat.value.clamp(0, 100)}점'), findsWidgets);
        expect(find.text('${stat.value.clamp(0, 100)}%'), findsNothing);
      }
      expect(find.text('미리보기 · 샘플 학습 데이터'), findsNothing);
    },
  );
}
