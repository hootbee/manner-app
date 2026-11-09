import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/fake/wardrobe_preview.dart';
import 'package:mannerfit/screens/wardrobe_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    WardrobePreview store, {
    bool shop = false,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      WardrobeScreen(partner: MannerPartner.dog, shop: shop),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('purchase adds inventory and insufficient coins do not charge', (
    tester,
  ) async {
    final store = WardrobePreview();
    addTearDown(store.dispose);
    await mount(tester, store, shop: true);
    await tester.tap(find.byKey(const ValueKey('outfit-hoodie')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.state.value.coins, 150);
    await tester.tap(find.byKey(const ValueKey('outfit-hoodie')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('구매하기'));
    await tester.pumpAndSettle();
    expect(store.state.value.coins, 50);
    expect(store.state.value.owned.contains('hoodie'), isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outfit-bear')),
      150,
    );
    await tester.tap(find.byKey(const ValueKey('outfit-bear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('구매하기'));
    await tester.pumpAndSettle();
    expect(find.text('코인이 부족해요.'), findsOneWidget);
    expect(store.state.value.coins, 50);
    expect(store.state.value.owned.contains('bear'), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preview is discarded on back; apply commits owned outfit', (
    tester,
  ) async {
    final store = WardrobePreview();
    addTearDown(store.dispose);
    await mount(tester, store);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outfit-trench')),
      150,
    );
    await tester.tap(find.byKey(const ValueKey('outfit-trench')));
    await tester.pumpAndSettle();
    expect(store.state.value.equipped, isEmpty);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(store.state.value.equipped, isEmpty);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ClothingCharacter>(find.byType(ClothingCharacter)).outfit,
      'suit',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('outfit-trench')),
      150,
    );
    await tester.tap(find.byKey(const ValueKey('outfit-trench')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();
    expect(store.state.value.equipped[MannerPartner.dog.name], 'trench');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ClothingCharacter>(find.byType(ClothingCharacter)).outfit,
      'trench',
    );
    expect(tester.takeException(), isNull);
  });
}
