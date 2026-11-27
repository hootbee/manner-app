import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'partner_artwork.dart';
import 'fitted_partner_clothes.dart';
import 'wardrobe_catalog.dart';
import 'wardrobe_room.dart';
import 'wardrobe_visuals.dart';
import 'partner_selection_screen.dart';

typedef WardrobeView = ({
  int coins,
  Set<String> owned,
  Map<String, String> equipped,
});
typedef ClothingItem = ({String id, String name, int price, bool locked});

/// Injected by the prototype entry point; screens only display values and send intents.
class WardrobeBinding extends InheritedWidget {
  const WardrobeBinding({
    super.key,
    required this.state,
    required this.catalog,
    required this.purchase,
    required this.equip,
    required super.child,
  });
  final ValueListenable<WardrobeView> state;
  final List<ClothingItem> catalog;
  final String Function(String) purchase;
  final void Function(String, String) equip;
  static WardrobeBinding? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WardrobeBinding>();
  @override
  bool updateShouldNotify(WardrobeBinding oldWidget) =>
      state != oldWidget.state || catalog != oldWidget.catalog;
}

class AppliedClothingCharacter extends StatelessWidget {
  const AppliedClothingCharacter({super.key, required this.partner});
  final MannerPartner partner;
  @override
  Widget build(BuildContext context) {
    final binding = WardrobeBinding.maybeOf(context);
    if (binding == null) {
      return PartnerArtwork(partner: partner);
    }
    return ValueListenableBuilder<WardrobeView>(
      valueListenable: binding.state,
      builder: (context, data, _) => ClothingCharacter(
        partner: partner,
        outfit: data.equipped[partner.name] ?? 'suit',
        equipment: data.equipped,
      ),
    );
  }
}

class PreviewCoinLabel extends StatelessWidget {
  const PreviewCoinLabel({super.key});
  @override
  Widget build(BuildContext context) {
    final binding = WardrobeBinding.maybeOf(context);
    if (binding == null) {
      return const Text(
        '—\n꾸미기 코인',
        style: TextStyle(fontSize: 12, height: 1.5),
      );
    }
    return ValueListenableBuilder<WardrobeView>(
      valueListenable: binding.state,
      builder: (context, data, _) => Text(
        '${data.coins}\n꾸미기 코인 (체험)',
        style: const TextStyle(fontSize: 12, height: 1.5),
      ),
    );
  }
}

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.partner, this.shop = false});
  final MannerPartner partner;
  final bool shop;
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  int _category = 1, _filter = 0;
  final Map<int, String> _draft = {};
  bool _buying = false;
  static const _ink = Color(0xFF191D1A);
  void _notice(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  Future<void> _buy(WardrobeBinding binding, ClothingItem item) async {
    if (_buying) return;
    if (item.locked) {
      _notice('보유 배지 조건을 달성하면 구매할 수 있어요.');
      return;
    }
    if (binding.state.value.owned.contains(item.id)) {
      _notice('이미 보유한 아이템이에요.');
      return;
    }
    setState(() => _buying = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('아이템 구매'),
        content: Text('${item.name}을(를) ${item.price} 코인으로 구매할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('구매하기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _buying = false);
    if (confirmed != true) return;
    final result = binding.purchase(item.id);
    _notice(switch (result) {
      'ok' => '구매했어요! 캐릭터 꾸미기에서 적용해보세요.',
      'insufficient' => '코인이 부족해요.',
      'owned' => '이미 보유한 아이템이에요.',
      'locked' => '보유 배지 조건을 확인해주세요.',
      _ => '지금은 구매할 수 없어요.',
    });
  }

  @override
  Widget build(BuildContext context) {
    final binding = WardrobeBinding.maybeOf(context);
    if (binding == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('캐릭터 꾸미기')),
        body: const Center(child: Text('꾸미기 미리보기를 준비 중이에요.')),
      );
    }
    return ValueListenableBuilder<WardrobeView>(
      valueListenable: binding.state,
      builder: (context, data, _) {
        final selection = <int, String>{
          for (var i = 0; i < 6; i++)
            i:
                _draft[i] ??
                data.equipped[equipmentKey(widget.partner.name, i)] ??
                wardrobeDefaults[i],
        };
        final selected = selection[_category]!;
        final previewEquipment = <String, String>{
          for (final e in selection.entries)
            equipmentKey(widget.partner.name, e.key): e.value,
        };
        final items = binding.catalog
            .where(
              (item) =>
                  wardrobeCategory(item.id) == _category &&
                  (widget.shop
                      ? item.price > 0
                      : _filter == 0 ||
                            (_filter == 1
                                ? data.owned.contains(item.id)
                                : !data.owned.contains(item.id))),
            )
            .toList();
        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF9F9F9),
            title: Text(
              widget.shop ? '꾸미기 상점' : '캐릭터 꾸미기',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            centerTitle: !widget.shop,
            actions: [
              if (widget.shop)
                IconButton(
                  tooltip: '보유 의상 보기',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WardrobeScreen(partner: widget.partner),
                    ),
                  ),
                  icon: const Icon(Icons.checkroom_outlined),
                ),
            ],
          ),
          bottomNavigationBar: widget.shop
              ? null
              : SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed:
                        selection.values.any((id) => !data.owned.contains(id))
                        ? null
                        : () {
                            for (final entry in selection.entries) {
                              binding.equip(
                                equipmentKey(widget.partner.name, entry.key),
                                entry.value,
                              );
                            }
                            Navigator.of(context).pop();
                          },
                    child: const Text('적용하기'),
                  ),
                ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (widget.shop)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F1F0),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '나의 꾸미기 코인',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const WardrobeCoin(size: 28),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${data.coins}',
                                    key: const Key('coin-balance'),
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (widget.shop) const SizedBox(height: 12),
                      _tabs(
                        wardrobeCategories,
                        _category,
                        (i) => setState(() => _category = i),
                      ),
                      const SizedBox(height: 12),
                      if (!widget.shop) ...[
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                WardrobeRoom(
                                  background: selection[5]!,
                                  furniture: selection[3]!,
                                  prop: selection[4]!,
                                ),
                                Align(
                                  alignment: const Alignment(0, .75),
                                  child: SizedBox(
                                    width: 180,
                                    height: 210,
                                    child: ClothingCharacter(
                                      partner: widget.partner,
                                      outfit: selection[1]!,
                                      equipment: previewEquipment,
                                    ),
                                  ),
                                ),
                                for (final direction in [-1, 1])
                                  Align(
                                    alignment: Alignment(
                                      direction.toDouble(),
                                      .15,
                                    ),
                                    child: IconButton.filledTonal(
                                      tooltip: direction < 0
                                          ? '이전 아이템'
                                          : '다음 아이템',
                                      onPressed: () {
                                        final ownedItems = binding.catalog
                                            .where(
                                              (e) =>
                                                  wardrobeCategory(e.id) ==
                                                      _category &&
                                                  data.owned.contains(e.id),
                                            )
                                            .toList();
                                        if (ownedItems.isEmpty) return;
                                        final at = ownedItems.indexWhere(
                                          (e) => e.id == selected,
                                        );
                                        setState(
                                          () => _draft[_category] =
                                              ownedItems[(at + direction) %
                                                      ownedItems.length]
                                                  .id,
                                        );
                                      },
                                      icon: Icon(
                                        direction < 0
                                            ? Icons.chevron_left
                                            : Icons.chevron_right,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tabs(
                          ['전체', '보유한 아이템', '미보유 아이템'],
                          _filter,
                          (i) => setState(() => _filter = i),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        '체험용 꾸미기 · 적용 전 변경은 저장되지 않아요.',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      '아직 준비된 아이템이 없어요.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = items[index];
                      final owned = data.owned.contains(item.id);
                      final active = !widget.shop && selected == item.id;
                      return Material(
                        color: owned && widget.shop
                            ? const Color(0xFFE7E8E7)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: active ? _ink : const Color(0xFFE4E5E4),
                            width: active ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('outfit-${item.id}'),
                          onTap: () {
                            if (widget.shop) {
                              _buy(binding, item);
                            } else if (owned) {
                              setState(() => _draft[_category] = item.id);
                            } else {
                              _notice('상점에서 구매한 후 적용할 수 있어요.');
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      item.id.startsWith('bg-')
                                          ? SizedBox(
                                              width: 120,
                                              height: 90,
                                              child: WardrobeRoom(
                                                background: item.id,
                                              ),
                                            )
                                          : WardrobeItemArt(id: item.id),
                                      if (item.locked ||
                                          (widget.shop &&
                                              (owned ||
                                                  data.coins < item.price)))
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: CircleAvatar(
                                            radius: 13,
                                            backgroundColor: _ink,
                                            child: Icon(
                                              owned
                                                  ? Icons.check
                                                  : Icons.lock_outline,
                                              size: 17,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  item.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (owned)
                                  const Text(
                                    '보유함',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  )
                                else if (item.locked)
                                  const Text(
                                    '보유 배지 부족',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9C6355),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const WardrobeCoin(size: 14),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${item.price}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: data.coins < item.price
                                              ? const Color(0xFFAC5136)
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: items.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.shop ? 2 : 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: widget.shop ? 164 : 133,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabs(List<String> labels, int selected, ValueChanged<int> onSelect) =>
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: List.generate(
            labels.length,
            (i) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == i ? _ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected == i ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Equipped room uses the same presentation as the wardrobe preview.
class AppliedWardrobeRoom extends StatelessWidget {
  const AppliedWardrobeRoom({super.key, required this.partner});
  final MannerPartner partner;
  @override
  Widget build(BuildContext context) {
    final binding = WardrobeBinding.maybeOf(context);
    if (binding == null) return const WardrobeRoom();
    return ValueListenableBuilder<WardrobeView>(
      valueListenable: binding.state,
      builder: (context, data, _) => WardrobeRoom(
        background: data.equipped[equipmentKey(partner.name, 5)] ?? 'bg-room',
        furniture:
            data.equipped[equipmentKey(partner.name, 3)] ?? 'furniture-none',
        prop: data.equipped[equipmentKey(partner.name, 4)] ?? 'prop-none',
      ),
    );
  }
}

/// One canonical body keeps clothes and accessories attached through every pose.
class ClothingCharacter extends StatelessWidget {
  const ClothingCharacter({
    super.key,
    required this.partner,
    required this.outfit,
    this.equipment = const {},
  });
  final MannerPartner partner;
  final String outfit;
  final Map<String, String> equipment;
  @override
  Widget build(BuildContext context) => FittedPartnerClothes(
    partner: partner,
    outfit: outfit,
    hat: equipment[equipmentKey(partner.name, 0)] ?? 'hat-none',
    accessory: equipment[equipmentKey(partner.name, 2)] ?? 'acc-none',
  );
}
