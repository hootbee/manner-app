import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/wardrobe_preview.dart';
import 'package:mannerfit/screens/wardrobe_catalog.dart';

void main() {
  test(
    'room purchases share inventory and equipment rejects the wrong slot',
    () {
      final shop = WardrobePreview();
      addTearDown(shop.dispose);
      expect(shop.purchase('bg-park'), 'ok');
      expect(shop.purchase('prop-mug'), 'ok');
      expect(shop.state.value.coins, 30);
      shop.equip(equipmentKey('dog', 5), 'bg-park');
      shop.equip(equipmentKey('dog', 4), 'prop-mug');
      shop.equip(equipmentKey('dog', 0), 'hat-beanie');
      shop.equip(equipmentKey('dog', 2), 'acc-watch');
      shop.equip(equipmentKey('dog', 3), 'furniture-rug');
      shop.equip('dog', 'school');
      final before = shop.state.value;
      shop.equip('dog', 'prop-mug');
      expect(shop.state.value, before);
      expect(shop.state.value.equipped.length, 6);
      expect(shop.purchase('bg-park'), 'owned');
      expect(shop.state.value.coins, 30);
    },
  );
  test(
    'purchase charges once, rejects insufficient coins and unknown items',
    () {
      final shop = WardrobePreview();
      addTearDown(shop.dispose);
      expect(shop.purchase('hoodie'), 'ok');
      expect(shop.state.value.coins, 50);
      expect(shop.purchase('hoodie'), 'owned');
      expect(shop.state.value.coins, 50);
      expect(shop.purchase('black-suit'), 'insufficient');
      expect(shop.purchase('unknown'), 'unavailable');
      expect(shop.state.value.owned.contains('black-suit'), isFalse);
      shop.equip('dog', 'black-suit');
      expect(shop.state.value.equipped, isEmpty);
      shop.equip('dog', 'hoodie');
      expect(shop.state.value.equipped['dog'], 'hoodie');
    },
  );
}
