import 'wardrobe_catalog.dart';
import 'wardrobe_samples.dart';
import 'package:flutter/foundation.dart';

/// Disposable shop simulation for main_prototype.dart only. Never writes records.
class WardrobePreview {
  static const catalog = wardrobeCatalog;
  final state =
      ValueNotifier<
        ({int coins, Set<String> owned, Map<String, String> equipped})
      >((
        coins: 150,
        owned: Set.unmodifiable({
          'suit',
          'trench',
          'school',
          'bear',
          'hat-none',
          'hat-beanie',
          'acc-none',
          'acc-watch',
          'furniture-none',
          'furniture-rug',
          'prop-none',
          'prop-umbrella',
          'bg-room',
        }),
        equipped: const {},
      ));
  String purchase(String id) {
    final matches = catalog.where((item) => item.id == id);
    if (matches.isEmpty) return 'unavailable';
    final item = matches.first;
    final current = state.value;
    if (current.owned.contains(id)) return 'owned';
    if (item.locked) return 'locked';
    if (current.coins < item.price) return 'insufficient';
    state.value = (
      coins: current.coins - item.price,
      owned: Set.unmodifiable({...current.owned, id}),
      equipped: current.equipped,
    );
    return 'ok';
  }

  void equip(String partner, String id) {
    final current = state.value;
    if (!current.owned.contains(id)) return;
    final slot = int.tryParse(partner.split(':').last) ?? 1;
    if (slot != wardrobeCategory(id)) return;
    state.value = (
      coins: current.coins,
      owned: current.owned,
      equipped: Map.unmodifiable({...current.equipped, partner: id}),
    );
  }

  void dispose() => state.dispose();
}
