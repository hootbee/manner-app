import 'package:flutter/foundation.dart';

/// Disposable shop simulation for main_prototype.dart only. Never writes records.
class WardrobePreview {
  static const catalog = <({String id, String name, int price, bool locked})>[
    (id: 'suit', name: '기본 정장', price: 0, locked: false),
    (id: 'black-suit', name: '블랙 수트', price: 100, locked: false),
    (id: 'hoodie', name: '화이트 후드', price: 100, locked: false),
    (id: 'varsity', name: '야구 점퍼', price: 50, locked: false),
    (id: 'trench', name: '탐정 코트', price: 50, locked: false),
    (id: 'bear', name: '곰돌이 잠옷', price: 100, locked: false),
    (id: 'stripe', name: '스트라이프 티', price: 50, locked: false),
    (id: 'leather', name: '가죽 재킷', price: 150, locked: true),
    (id: 'cardigan', name: '니트 카디건', price: 100, locked: false),
  ];
  final state =
      ValueNotifier<
        ({int coins, Set<String> owned, Map<String, String> equipped})
      >((
        coins: 150,
        owned: Set.unmodifiable({'suit', 'trench'}),
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
    state.value = (
      coins: current.coins,
      owned: current.owned,
      equipped: Map.unmodifiable({...current.equipped, partner: id}),
    );
  }

  void dispose() => state.dispose();
}
