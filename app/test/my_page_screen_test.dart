import 'package:mannerfit/fake/wardrobe_preview.dart';
import 'package:mannerfit/screens/wardrobe_screen.dart';
import 'package:mannerfit/screens/partner_artwork.dart';
import 'package:mannerfit/screens/settings_screen.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/screens/stat_share_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/my_page_screen.dart';
import 'package:mannerfit/screens/home_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  setUp(() => backend = FakeBackend());

  testWidgets(
    'live profile hides wardrobe and badge preview; home keeps sparkles',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MyPageScreen(partner: MannerPartner.dog)),
      );
      expect(find.text('캐릭터 꾸미기'), findsNothing);
      expect(find.text('꾸미기 상점'), findsNothing);
      expect(find.textContaining('획득한 배지'), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(partner: MannerPartner.dog)),
      );
      final artwork = tester.widget<PartnerArtwork>(
        find
            .descendant(
              of: find.byType(AppliedClothingCharacter),
              matching: find.byType(PartnerArtwork),
            )
            .first,
      );
      expect(artwork.showSparkles, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final shop in [false, true]) {
    testWidgets(
      'profile opens wardrobe with shop=$shop and keeps selected partner',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = WardrobePreview();
        addTearDown(store.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => WardrobeBinding(
              state: store.state,
              catalog: WardrobePreview.catalog,
              purchase: store.purchase,
              equip: store.equip,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            home: const MyPageScreen(partner: MannerPartner.cat),
          ),
        );
        final menu = find.text(shop ? '꾸미기 상점' : '캐릭터 꾸미기');
        await tester.ensureVisible(menu);
        await tester.pump();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        final screen = tester.widget<WardrobeScreen>(
          find.byType(WardrobeScreen),
        );
        expect(screen.partner, MannerPartner.cat);
        expect(screen.shop, shop);
        expect(find.textContaining('획득한 배지'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'selected partner reacts to tap and drag; menu remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: MyPageScreen(partner: MannerPartner.cat)),
      );
      expect(find.text('냥냥이'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-character')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('꺄르르! 함께하니 즐거워요!'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('profile-character')),
        const Offset(100, 0),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final transform = tester.widget<Transform>(
        find.byKey(const Key('character-turn')),
      );
      expect(transform.transform.entry(0, 0), isNot(1));
      await tester.ensureVisible(find.text('스탯 공유'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('스탯 공유'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StatShareScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home opens profile with the selected partner', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(partner: MannerPartner.monkey, preview: true),
      ),
    );
    await tester.tap(find.text('마이페이지'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(
      tester.widget<MyPageScreen>(find.byType(MyPageScreen)).preview,
      isTrue,
    );

    expect(find.text('몽몽이'), findsOneWidget);
    await tester.tap(find.text('홈').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MyPageScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile settings icon opens frontend settings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MyPageScreen(partner: MannerPartner.dog)),
    );
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('알림 설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile settings menu opens frontend settings', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: MyPageScreen(partner: MannerPartner.dog)),
    );
    await tester.ensureVisible(find.text('설정'));
    await tester.pump();
    await tester.tap(find.text('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
