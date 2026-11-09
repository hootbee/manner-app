import 'challenges_screen.dart';
import 'digital_questions.dart';
import 'school_questions.dart';
import 'conversation_questions.dart';
import 'dining_questions.dart';
import 'public_questions.dart';
import 'transport_progress.dart';
import 'transport_questions.dart';
import 'transport_lesson_screen.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';
import 'partner_artwork.dart';
import 'daily_mission_progress.dart';
import 'learning_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.partner,
    this.progress = const DailyMissionProgress(
      completed: int.fromEnvironment('DEMO_COMPLETED'),
    ),
    this.onLearn,
  });
  final MannerPartner partner;
  final DailyMissionProgress progress;
  final VoidCallback? onLearn;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    TransportProgress.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    TransportProgress.instance.removeListener(_refresh);
    super.dispose();
  }

  bool _expanded = false;
  int? _focusedRecord;
  void _openLearning() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const LearningCategoryScreen()),
  );
  Future<void> _openChallenges() async {
    final destination = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ChallengesScreen()));
    if (mounted && destination == 'learn') _openLearning();
  }
  void _notice(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  Widget _card(Widget child, {EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? EdgeInsets.all(_expanded ? 10 : 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE7E8EA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final store = TransportProgress.instance;
    final records = store.todayRecords;
    final p = records.isEmpty
        ? widget.progress
        : DailyMissionProgress(completed: records.length.clamp(0, 10));
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
          ),
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: InkWell(
                  onTap: () {
                    if (i == 1) {
                      _openLearning();
                    } else if (i == 2) {
                      _openChallenges();
                    } else if (i != 0) {
                      _notice('다음 화면은 준비 중이에요.');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          [
                            Icons.home,
                            Icons.menu_book_outlined,
                            Icons.emoji_events_outlined,
                            Icons.person_outline,
                          ][i],
                          color: i == 0 ? Colors.black : Colors.grey,
                          size: 25,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ['홈', '학습하기', '도전과제', '마이페이지'][i],
                          style: TextStyle(
                            fontSize: 10,
                            color: i == 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              children: [
                _MotionSize(
                  duration: Duration(milliseconds: reduced ? 0 : 280),
                  child: SizedBox(
                    height: _expanded ? 160 : 193,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 10,
                          top: 6,
                          child: Transform.scale(
                            scale: _expanded ? .8 : 1,
                            alignment: Alignment.topLeft,
                            child: const _Wordmark(),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: '알림',
                            onPressed: () => _notice('새로운 알림이 없어요.'),
                            icon: const Badge(
                              smallSize: 6,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.notifications_none,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 32,
                          width: 115,
                          height: _expanded ? 108 : 132,
                          child: PartnerArtwork(partner: widget.partner),
                        ),
                        Positioned(
                          left: 10,
                          top: _expanded ? 46 : 65,
                          child: const Text(
                            '안녕하세요, 준님!',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: _expanded ? 75 : 96,
                          child: const Text(
                            '오늘도 작은 배려를 실천해 볼까요?',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: _expanded ? 93 : 119,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: _expanded ? 0 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: _expanded ? 20 : 25,
                                  child: AmbientMotion(
                                    builder: (_, t) =>
                                        CustomPaint(painter: _Flame(t)),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  '7일 연속 학습',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _card(
                            Row(
                              children: [
                                Text(
                                  'Lv. ${2 + store.xp ~/ 400}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 11,
                                    child: _LitGauge(
                                      value: (store.xp % 400) / 400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${store.xp % 400} / 400 XP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4F4F4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 36),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 공통 매너 테마',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '작은 배려가 만드는 하루',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '오늘은 일상 속에서 다른 사람을 배려하는\n매너를 배워봐요.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.track_changes, size: 25),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              '오늘의 데일리 미션',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              '${p.total}문제',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduced ? 0 : 220),
                          child: Text(
                            p.encouragement,
                            key: ValueKey(p.encouragement),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: _expanded ? 78 : 96,
                            height: _expanded ? 78 : 96,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: _LitGauge(
                                    value: p.fraction,
                                    circular: true,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(p.fraction * 100).round()}%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${p.completed} / ${p.total}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 85,
                            margin: const EdgeInsets.symmetric(horizontal: 13),
                            color: const Color(0xFFE1E1E1),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  '오늘의 테마 학습',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 5, bottom: 10),
                                  child: Text(
                                    '대중교통 상황 속 기본 매너 익히기',
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.4,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                PrismaticButton(
                                  label: p.action,
                                  complete: p.isComplete,
                                  onPressed:
                                      widget.onLearn ??
                                      () {
                                        final next = transportQuestions
                                            .indexWhere(
                                              (q) =>
                                                  store
                                                      .sessions[q.id]
                                                      ?.firstCompletedAt ==
                                                  null,
                                            );
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                TransportLessonScreen(
                                                  index: next < 0 ? 0 : next,
                                                ),
                                          ),
                                        );
                                      },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _MotionSize(
                        duration: Duration(milliseconds: reduced ? 0 : 280),
                        alignment: Alignment.topCenter,
                        child: !_expanded
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        p.total,
                                        (i) => Semantics(
                                          label:
                                              '${i + 1}번 문제 ${i < p.completed ? '완료' : '미완료'}',
                                          child: SizedBox(
                                            width: 26,
                                            height: 24,
                                            child: InkWell(
                                              onTap: i < p.completed
                                                  ? () => setState(
                                                      () => _focusedRecord = i,
                                                    )
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Center(
                                                child: Icon(
                                                  i < p.completed
                                                      ? Icons.check_circle
                                                      : Icons.circle,
                                                  color: i < p.completed
                                                      ? Colors.black
                                                      : const Color(0xFFDDDDDD),
                                                  size: 17,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (p.completed == 0)
                                      const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Text(
                                          '아직 학습 기록이 없어요. 첫 문제를 시작해 볼까요?',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    else ...[
                                      if (_focusedRecord != null &&
                                          _focusedRecord! < p.completed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            '${_focusedRecord! + 1}번 문제 완료 · ${records.isEmpty ? p.timeAt(_focusedRecord!) : records[_focusedRecord!].value.firstCompletedAt!.toLocal().toString().substring(11, 16)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      for (var i = 0; i < p.completed; i++)
                                        InkWell(
                                          onTap: () => setState(
                                            () => _focusedRecord = i,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                              horizontal: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _focusedRecord == i
                                                  ? const Color(0xFFF1F1F1)
                                                  : null,
                                              border: const Border(
                                                top: BorderSide(
                                                  color: Color(0xFFF0F0F0),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 9,
                                                  backgroundColor: const Color(
                                                    0xFFE7E7E7,
                                                  ),
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    records.isEmpty
                                                        ? p.titleAt(i)
                                                        : [
                                                                ...transportQuestions,
                                                                ...publicQuestions,
                                                                ...diningQuestions,
                                                                ...conversationQuestions,
                                                                ...schoolQuestions,
                                                                ...digitalQuestions,
                                                              ]
                                                              .firstWhere(
                                                                (q) =>
                                                                    q.id ==
                                                                    records[i]
                                                                        .key,
                                                              )
                                                              .title
                                                              .replaceAll(
                                                                '\n',
                                                                ' ',
                                                              ),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  records.isEmpty
                                                      ? p.timeAt(i)
                                                      : '${records[i].value.firstCompletedAt!.hour.toString().padLeft(2, '0')}:${records[i].value.firstCompletedAt!.minute.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE7E7E7)),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _expanded ? '학습 기록 접기' : '학습 기록 펼치기',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 3 ? 0 : 5),
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE7E7E7)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => i == 0
                                ? _openLearning()
                                : i == 1
                                ? _openChallenges()
                                : _notice('다음 화면은 준비 중이에요.'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Icon(
                                    [
                                      Icons.menu_book_outlined,
                                      Icons.emoji_events_outlined,
                                      Icons.event_available_outlined,
                                      Icons.bar_chart,
                                    ][i],
                                    size: 25,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    ['카테고리 학습', '도전과제', '출석체크', '나의 매너 스탯'][i],
                                    style: const TextStyle(fontSize: 9),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionSize extends StatelessWidget {
  const _MotionSize({
    required this.duration,
    required this.child,
    this.alignment = Alignment.center,
  });
  final Duration duration;
  final Widget child;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(duration: duration, alignment: alignment, child: child);
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 94,
    height: 46,
    child: FittedBox(
      child: SizedBox(
        width: 171,
        height: 85,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 351,
            maxWidth: 351,
            minHeight: 797,
            maxHeight: 797,
            child: Transform.translate(
              offset: const Offset(-89, -91),
              child: Image.asset(
                'assets/welcome/design_reference.webp',
                width: 351,
                height: 797,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LitGauge extends StatelessWidget {
  const _LitGauge({required this.value, this.circular = false});
  final double value;
  final bool circular;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(value * 100).round()}% 완료',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 650,
      ),
      builder: (_, v, _) => AmbientMotion(
        builder: (_, t) => CustomPaint(painter: _GaugePainter(v, t, circular)),
      ),
    ),
  );
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.t, this.circular);
  final double value, t;
  final bool circular;
  static const colors = [
    Color(0xFF9CD5FF),
    Color(0xFFD8B8FF),
    Color(0xFFFFDBAF),
    Color(0xFFA9E4CE),
    Color(0xFF9CD5FF),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final complete = value >= 1;
    final rect = Offset.zero & size;
    if (circular) {
      final circle = rect.deflate(6);
      final center = rect.center;
      final radius = circle.width / 2;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(
        center,
        radius,
        p
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFE1E1E1),
              Color.lerp(
                const Color(0xFFE8E8E8),
                const Color(0xFFF6F0FF),
                (.5 + .5 * math.sin(t * math.pi * 2)),
              )!,
            ],
          ).createShader(rect),
      );
      // Keep the completion ring dark; only a narrow sheen carries color.
      p.shader = null;
      p.color = const Color(0xFF252825);
      if (complete) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..color = const Color(
              0xFF252825,
            ).withValues(alpha: .08 + .03 * math.sin(t * math.pi * 2))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      if (value > 0) {
        canvas.drawArc(circle, -math.pi / 2, value * math.pi * 2, false, p);
      }
      if (complete) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6.5
            ..shader = SweepGradient(
              colors: [
                Colors.transparent,
                Colors.transparent,
                colors[0].withValues(alpha: .28),
                colors[1].withValues(alpha: .3),
                colors[2].withValues(alpha: .26),
                colors[3].withValues(alpha: .28),
                Colors.transparent,
                Colors.transparent,
              ],
              stops: const [0, .34, .4, .46, .52, .58, .64, 1],
              transform: GradientRotation(t * math.pi * 2),
            ).createShader(rect),
        );
      }
      final angle = -math.pi / 2 + value * math.pi * 2;
      final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (value > 0 && !complete) {
        canvas.drawCircle(
          tip,
          5,
          Paint()
            ..color = colors[(t * 4).floor() % 4].withValues(alpha: .55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    } else {
      final round = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(round, Paint()..color = const Color(0xFFE5E5E5));
      canvas.save();
      canvas.clipRRect(round);
      final fill = Rect.fromLTWH(0, 0, size.width * value, size.height);
      canvas.drawRect(fill, Paint()..color = const Color(0xFF292C29));
      final x = -size.width + t * size.width * 3;
      canvas.drawRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              colors[(t * 4).floor() % 4].withValues(alpha: .6),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(x, 0, size.width * .5, size.height)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      value != old.value || t != old.t || circular != old.circular;
}

class _Flame extends CustomPainter {
  const _Flame(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 30);
    final flicker = math.sin(t * math.pi * 10);
    final flame = Path()
      ..moveTo(12, 29)
      ..cubicTo(-2, 28, 0, 15, 7, 10)
      ..quadraticBezierTo(5, 17, 10, 16)
      ..quadraticBezierTo(16, 10, 12 + flicker, 1)
      ..cubicTo(25, 10, 28, 25, 12, 29)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..color = const Color(0xFFFFB45A).withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      flame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF292929), Color(0xFF4D3123), Color(0xFFE99B47)],
        ).createShader(const Rect.fromLTWH(0, 0, 24, 30)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 27)
        ..quadraticBezierTo(4, 23, 12, 16 + flicker)
        ..quadraticBezierTo(19, 24, 12, 27),
      Paint()..color = const Color(0xFFFFD79A),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Flame old) => t != old.t;
}
