import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../backend.dart';
import 'partner_artwork.dart';
import 'partner_selection_screen.dart';
import 'stat_image_export.dart';

class StatShareScreen extends StatefulWidget {
  const StatShareScreen({
    super.key,
    required this.home,
    required this.stats,
    required this.partner,
    this.preview = false,
    this.onSave = saveStatImage,
    this.onShare = shareStatImage,
  });
  final Home home;
  final List<AreaStat> stats;
  final MannerPartner partner;
  final bool preview;
  final StatImageAction onSave, onShare;
  @override
  State<StatShareScreen> createState() => _StatShareScreenState();
}

class _StatShareScreenState extends State<StatShareScreen> {
  final _cardKey = GlobalKey();
  Uint8List? _png;
  bool _busy = false, _preparing = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    try {
      var imageFailed = false;
      await precacheImage(
        const AssetImage('assets/welcome/growth_stages.webp'),
        context,
        onError: (error, stack) => imageFailed = true,
      );
      if (imageFailed) throw StateError('character image unavailable');
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('PNG encoding failed');
        if (mounted) {
          setState(() {
            _png = bytes.buffer.asUint8List();
            _preparing = false;
          });
        }
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _export(
    StatImageAction action,
    BuildContext buttonContext,
  ) async {
    if (_busy || _png == null) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    StatImageResult result;
    try {
      result = await action(_png!, origin);
    } catch (_) {
      result = StatImageResult.failed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (result) {
      StatImageResult.saved => '사진첩에 이미지를 저장했어요.',
      StatImageResult.downloaded => '이미지 다운로드를 요청했어요.',
      StatImageResult.opened => '공유 창을 열었어요.',
      StatImageResult.dismissed => null,
      StatImageResult.denied => '사진 저장 권한이 필요해요. 기기 설정에서 권한을 허용해주세요.',
      StatImageResult.noSpace => '저장 공간이 부족해요.',
      StatImageResult.unsupported => '이 기기에서는 지원하지 않아요. 이미지로 저장을 이용해주세요.',
      StatImageResult.failed => '처리하지 못했어요. 다시 시도하거나 이미지로 저장을 이용해주세요.',
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF9F9F9),
      title: const Text(
        '스탯 공유하기',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: StatShareCard(
                home: widget.home,
                stats: widget.stats,
                partner: widget.partner,
                preview: widget.preview,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_preparing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '공유 이미지를 준비하고 있어요.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (!_preparing && _png == null)
            TextButton(
              onPressed: () {
                setState(() => _preparing = true);
                _prepare();
              },
              child: const Text('이미지 준비 다시 시도'),
            ),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              key: const Key('save-stat-image'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF191D1A),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy || _png == null
                  ? null
                  : () => _export(widget.onSave, buttonContext),
              icon: const Icon(Icons.download_outlined),
              label: const Text('이미지로 저장'),
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              key: const Key('share-stat-image'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF191D1A),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy || _png == null
                  ? null
                  : () => _export(widget.onShare, buttonContext),
              icon: const Icon(Icons.share_outlined),
              label: Text(_busy ? '처리 중…' : '공유하기'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Only this card is exported. Navigation and action buttons stay outside the PNG.
class StatShareCard extends StatelessWidget {
  const StatShareCard({
    super.key,
    required this.home,
    required this.stats,
    required this.partner,
    this.preview = false,
  });
  final Home home;
  final List<AreaStat> stats;
  final MannerPartner partner;
  final bool preview;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE6E9E6), Colors.white, Color(0xFFEDEDED)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '매너스',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text(
                'M A N N E R S',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              const Text(
                '“좋은 매너가\n더 멋진 나를 만든다!”',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 158,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        left: 0,
                        bottom: 0,
                        width: constraints.maxWidth * .43,
                        height: 128,
                        child: const PartnerArtwork(
                          partner: MannerPartner.cat,
                          showSparkles: false,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: constraints.maxWidth * .43,
                        height: 128,
                        child: const PartnerArtwork(
                          partner: MannerPartner.monkey,
                          showSparkles: false,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: constraints.maxWidth * .21,
                        width: constraints.maxWidth * .58,
                        height: 158,
                        child: const PartnerArtwork(
                          partner: MannerPartner.dog,
                          showSparkles: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          partner.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          '작은 배려를 함께 배우는 매너 파트너',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        if (preview)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '미리보기 · 샘플 학습 데이터',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Lv. ${home.level}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LinearProgressIndicator(
                value: home.levelProgress.clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF476B5B),
                backgroundColor: const Color(0xFFE6E8E6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${home.xp} XP',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          '나의 매너 스탯',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (stats.isEmpty)
          const Text(
            '아직 표시할 학습 기록이 없어요.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          )
        else
          Wrap(
            runSpacing: 16,
            children: [
              for (final stat in stats)
                FractionallySizedBox(
                  widthFactor: 1 / 3,
                  child: Column(
                    children: [
                      Icon(
                        _icons[stat.area] ?? Icons.auto_stories_outlined,
                        size: 23,
                      ),
                      const SizedBox(height: 5),
                      Text(stat.area, style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 3),
                      Text(
                        '${stat.value.clamp(0, 100)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '작은 배려가 모여\n더 좋은 일상을 만들 수 있어요!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ),
      ],
    ),
  );
  static const _icons = <String, IconData>{
    '대화': Icons.forum_outlined,
    '식사': Icons.restaurant,
    '공공장소': Icons.park_outlined,
    '대중교통': Icons.directions_bus_outlined,
    '학교·직장': Icons.business_center_outlined,
    '디지털': Icons.devices_outlined,
    '연애': Icons.favorite_outline,
    '친구': Icons.people_outline,
    '어른·가족': Icons.family_restroom,
    '직장': Icons.business_center_outlined,
    '메시지': Icons.chat_bubble_outline,
  };
}
