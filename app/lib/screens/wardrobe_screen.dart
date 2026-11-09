import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'partner_artwork.dart';
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
      return PartnerArtwork(partner: partner, showSparkles: false);
    }
    return ValueListenableBuilder<WardrobeView>(
      valueListenable: binding.state,
      builder: (context, data, _) => ClothingCharacter(
        partner: partner,
        outfit: data.equipped[partner.name] ?? 'suit',
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
  String? _draft;
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
      _notice('이미 보유한 의상이에요.');
      return;
    }
    setState(() => _buying = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('의상 구매'),
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
      'ok' => '구매했어요! 캐릭터 꾸미기에서 입어보세요.',
      'insufficient' => '코인이 부족해요.',
      'owned' => '이미 보유한 의상이에요.',
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
        final equipped = data.equipped[widget.partner.name] ?? 'suit';
        final selected = _draft ?? equipped;
        final items = binding.catalog
            .where(
              (item) => widget.shop
                  ? item.price > 0
                  : _filter == 0 ||
                        (_filter == 1
                            ? data.owned.contains(item.id)
                            : !data.owned.contains(item.id)),
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
                    onPressed: _category != 1 || !data.owned.contains(selected)
                        ? null
                        : () {
                            binding.equip(widget.partner.name, selected);
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
                                  const Icon(
                                    Icons.monetization_on_outlined,
                                    color: Color(0xFFB58C4E),
                                  ),
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
                        ['모자', '의상', '액세서리', '배경'],
                        _category,
                        (i) => setState(() => _category = i),
                      ),
                      const SizedBox(height: 12),
                      if (!widget.shop) ...[
                        Container(
                          height: 255,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const RadialGradient(
                              colors: [Colors.white, Color(0xFFE8EAE8)],
                              radius: .85,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClothingCharacter(
                                  partner: widget.partner,
                                  outfit: selected,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  widget.partner.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
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
                        '미리보기 · 코인과 의상은 앱 재실행 시 초기화돼요.',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (_category != 1 || items.isEmpty)
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
                              setState(() => _draft = item.id);
                            } else {
                              _notice('상점에서 구매한 후 입을 수 있어요.');
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
                                      CustomPaint(
                                        size: const Size(100, 90),
                                        painter: _ClothesPainter(item.id),
                                      ),
                                      if (item.locked || (owned && widget.shop))
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: CircleAvatar(
                                            radius: 13,
                                            backgroundColor: _ink,
                                            child: Icon(
                                              item.locked
                                                  ? Icons.lock_outline
                                                  : Icons.check,
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
                                      const Icon(
                                        Icons.monetization_on_outlined,
                                        size: 13,
                                        color: Color(0xFFB58C4E),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${item.price}',
                                        style: const TextStyle(fontSize: 11),
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

/// Existing partner art plus a code-drawn garment for the prototype wardrobe.
class ClothingCharacter extends StatelessWidget {
  const ClothingCharacter({
    super.key,
    required this.partner,
    required this.outfit,
  });
  final MannerPartner partner;
  final String outfit;
  @override
  Widget build(BuildContext context) => AmbientMotion(
    builder: (context, t) => Stack(
      fit: StackFit.expand,
      children: [
        PartnerArtwork(partner: partner, showSparkles: false),
        if (outfit != 'suit')
          IgnorePointer(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, size) => Align(
                    alignment: const Alignment(0, .25),
                    child: SizedBox(
                      width: size.maxWidth * .58,
                      height: size.maxHeight * .42,
                      child: CustomPaint(painter: _ClothesPainter(outfit)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ClothesPainter extends CustomPainter {
  const _ClothesPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 90);
    final light = id == 'hoodie' || id == 'stripe';
    final fill = Paint()
      ..color = light
          ? const Color(0xFFF9F9F9)
          : id == 'trench'
          ? const Color(0xFF969892)
          : id == 'bear'
          ? const Color(0xFFB5B6B3)
          : const Color(0xFF393C3A);
    final line = Paint()
      ..color = const Color(0xFF171A18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final shape = Path()
      ..moveTo(33, 12)
      ..quadraticBezierTo(50, 20, 67, 12)
      ..lineTo(81, 20)
      ..lineTo(95, 58)
      ..lineTo(79, 65)
      ..lineTo(74, 43)
      ..lineTo(77, 81)
      ..quadraticBezierTo(50, 86, 23, 81)
      ..lineTo(26, 43)
      ..lineTo(21, 65)
      ..lineTo(5, 58)
      ..lineTo(19, 20)
      ..close();
    canvas.drawPath(shape, fill);
    canvas.drawPath(shape, line);
    if (id == 'hoodie' || id == 'bear') {
      canvas.drawPath(
        Path()
          ..moveTo(33, 12)
          ..quadraticBezierTo(50, -3, 67, 12)
          ..quadraticBezierTo(50, 36, 33, 12),
        line,
      );
      canvas.drawLine(const Offset(44, 29), const Offset(44, 49), line);
      canvas.drawLine(const Offset(56, 29), const Offset(56, 49), line);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(35, 58, 30, 14),
          const Radius.circular(5),
        ),
        line,
      );
    } else if (id == 'stripe') {
      canvas.save();
      canvas.clipPath(shape);
      for (double y = 30; y < 82; y += 12) {
        canvas.drawRect(
          Rect.fromLTWH(5, y, 90, 5),
          Paint()..color = const Color(0xFF393C3A),
        );
      }
      canvas.restore();
    } else {
      canvas.drawLine(const Offset(50, 22), const Offset(50, 81), line);
      canvas.drawPath(
        Path()
          ..moveTo(33, 12)
          ..lineTo(41, 43)
          ..lineTo(50, 27)
          ..lineTo(59, 43)
          ..lineTo(67, 12),
        line,
      );
      if (id == 'varsity') {
        canvas.drawLine(
          const Offset(24, 27),
          const Offset(18, 57),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 7,
        );
        canvas.drawLine(
          const Offset(76, 27),
          const Offset(82, 57),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 7,
        );
      }
      for (double y = 47; y < 78; y += 12) {
        canvas.drawCircle(Offset(54, y), 1.6, Paint()..color = Colors.white);
      }
    }
    if (id == 'bear') {
      final p = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(43, 47), 5, p);
      canvas.drawCircle(const Offset(57, 47), 5, p);
      canvas.drawOval(const Rect.fromLTWH(40, 46, 20, 23), p);
      canvas.drawCircle(const Offset(46, 54), 1.2, Paint());
      canvas.drawCircle(const Offset(54, 54), 1.2, Paint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClothesPainter oldDelegate) => oldDelegate.id != id;
}
