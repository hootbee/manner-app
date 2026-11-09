import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/fake/wardrobe_preview.dart';

void main() {
  test(
    'purchase charges once, rejects insufficient coins and locked items',
    () {
      final shop = WardrobePreview();
      addTearDown(shop.dispose);
      expect(shop.purchase('hoodie'), 'ok');
      expect(shop.state.value.coins, 50);
      expect(shop.purchase('hoodie'), 'owned');
      expect(shop.state.value.coins, 50);
      expect(shop.purchase('bear'), 'insufficient');
      expect(shop.purchase('leather'), 'locked');
      expect(shop.state.value.owned.contains('bear'), isFalse);
      shop.equip('dog', 'bear');
      expect(shop.state.value.equipped, isEmpty);
      shop.equip('dog', 'hoodie');
      expect(shop.state.value.equipped['dog'], 'hoodie');
    },
  );
}
