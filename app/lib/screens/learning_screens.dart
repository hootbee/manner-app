import 'challenges_screen.dart';
import 'transport_progress.dart';
import 'transport_lesson_screen.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'learning_catalog.dart';
import 'partner_artwork.dart';

const _ink = Color(0xFF202522);
const _green = Color(0xFF385C4D);
const _border = Color(0xFFE6E8E8);

class LearningCategoryScreen extends StatefulWidget {
  const LearningCategoryScreen({super.key});
  @override
  State<LearningCategoryScreen> createState() => _LearningCategoryScreenState();
}

class _LearningCategoryScreenState extends State<LearningCategoryScreen> {
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

  String _query = '';
  @override
  Widget build(BuildContext context) {
    final categories = learningCategories
        .where((c) => c.matches(_query))
        .toList();
    final completed = learningCategories.fold(0, (n, c) => n + c.completed);
    final total = learningCategories.fold(0, (n, c) => n + c.lessons.length);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      bottomNavigationBar: _LearningNavigation(
        onHome: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '매너 학습하기',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LearningSearchField(
                      hint: '어떤 매너를 배우고 싶으신가요?',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '전체 학습 진행도',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ProgressLine(
                            completed: completed,
                            total: total,
                            showCount: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (categories.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptySearch(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 160,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CategoryCard(
                      category: categories[i],
                      onTap: () {
                        final category = categories[i];
                        final categoryTitleMatches = matchesLearningQuery(
                          '${category.title} ${category.description}',
                          _query,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LearningLessonScreen(
                              category: category,
                              initialQuery: categoryTitleMatches ? '' : _query,
                            ),
                          ),
                        );
                      },
                    ),
                    childCount: categories.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LearningLessonScreen extends StatefulWidget {
  const LearningLessonScreen({
    super.key,
    required this.category,
    this.initialQuery = '',
    this.onLessonSelected,
  });
  final LearningCategory category;
  final String initialQuery;
  final ValueChanged<LearningLesson>? onLessonSelected;
  @override
  State<LearningLessonScreen> createState() => _LearningLessonScreenState();
}

class _LearningLessonScreenState extends State<LearningLessonScreen> {
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

  late String _query = widget.initialQuery;
  void _open(LearningLesson lesson) {
    if (widget.onLessonSelected != null) {
      widget.onLessonSelected!(lesson);
      return;
    }
    if ((widget.category.id == 'transport' ||
        widget.category.id == 'public' ||
        widget.category.id == 'dining' ||
        widget.category.id == 'conversation' ||
        widget.category.id == 'school-work' ||
        widget.category.id == 'digital')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransportLessonScreen(
            categoryId: widget.category.id,
            index: widget.category.lessons.indexOf(lesson),
          ),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${lesson.title} · 문제 화면은 다음 단계에서 연결됩니다.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final lessons = category.search(_query);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 174,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    width: 175,
                    height: 160,
                    child: ClipRect(
                      child: AmbientMotion(
                        builder: (context, t) {
                          final reduced = MediaQuery.disableAnimationsOf(
                            context,
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Transform.translate(
                                offset: reduced
                                    ? Offset.zero
                                    : Offset(
                                        math.sin(t * math.pi * 2) * 2.5,
                                        math.cos(t * math.pi * 2) * 1.5,
                                      ),
                                child: Transform.scale(
                                  scale: 1.055,
                                  child: _CategoryArt(
                                    index: category.artIndex,
                                    hero: true,
                                  ),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFAFAFA),
                                      Color(0x00FAFAFA),
                                    ],
                                    stops: [0, .48],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 0,
                    child: IconButton(
                      tooltip: '카테고리로 돌아가기',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 56,
                    right: 110,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 94,
                    width: 215,
                    child: Text(
                      category.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 7,
                    child: Text(
                      '${category.completed} / ${category.lessons.length} 완료',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProgressLine(
                completed: category.completed,
                total: category.lessons.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: LearningSearchField(
                hint: '세부 주제를 검색해보세요. (예: 자리, 소음)',
                initialValue: widget.initialQuery,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: lessons.isEmpty
                  ? const _EmptySearch()
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: lessons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final lesson = lessons[i];
                        return _LessonRow(
                          lesson: lesson,
                          number: category.lessons.indexOf(lesson) + 1,
                          onTap: () => _open(lesson),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningSearchField extends StatefulWidget {
  const LearningSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
  });
  final String hint, initialValue;
  final ValueChanged<String> onChanged;
  @override
  State<LearningSearchField> createState() => _LearningSearchFieldState();
}

class _LearningSearchFieldState extends State<LearningSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    textInputAction: TextInputAction.search,
    style: const TextStyle(fontSize: 13, color: _ink),
    onChanged: (value) {
      setState(() {});
      widget.onChanged(value);
    },
    decoration: InputDecoration(
      hintText: widget.hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.black45),
      prefixIcon: const Icon(Icons.search, size: 22, color: _ink),
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: '검색어 지우기',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged('');
              },
            ),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF5F6F6),
      contentPadding: const EdgeInsets.symmetric(vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(color: _green),
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});
  final LearningCategory category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${category.title}, ${category.completed}/${category.lessons.length} 완료',
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 94, child: _CategoryArt(index: category.artIndex)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${category.completed} / ${category.lessons.length} 완료',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF0F1F1),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Renders only each illustration from the supplied design reference, retaining its art style.
class _CategoryArt extends StatelessWidget {
  const _CategoryArt({required this.index, this.hero = false});
  final int index;
  final bool hero;
  // Shared artwork for category cards and detail headers.
  static const _assets = [
    'transport',
    'dining',
    'public',
    'conversation',
    'school-work',
    'digital',
  ];
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/welcome/category_${_assets[index]}.webp',
      fit: hero ? BoxFit.contain : BoxFit.cover,
      filterQuality: FilterQuality.high,
    ),
  );
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.completed,
    required this.total,
    this.showCount = false,
  });
  final int completed, total;
  final bool showCount;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(completed / total * 100).round()}% 완료',
    child: Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completed / total,
              minHeight: showCount ? 12 : 10,
              backgroundColor: const Color(0xFFE6E7E8),
              valueColor: const AlwaysStoppedAnimation(_green),
            ),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 12),
          Text(
            '$completed / $total',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
        const SizedBox(width: 12),
        Text(
          '${(completed / total * 100).round()}%',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _green,
          ),
        ),
      ],
    ),
  );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.number,
    required this.onTap,
  });
  final LearningLesson lesson;
  final int number;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final failed = lesson.hasFailed;
    final done = lesson.status == LessonStatus.completed;
    final ongoing = lesson.status == LessonStatus.inProgress;
    final label = done
        ? '완료'
        : ongoing
        ? '학습 중'
        : '시작';
    return Semantics(
      button: true,
      label: '$number. ${lesson.title}, $label',
      child: Material(
        key: ValueKey('lesson-${lesson.id}'),
        color: failed && !done
            ? const Color(0xFFFFF4EE)
            : done
            ? const Color(0xFFF0F4F1)
            : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(23),
          side: BorderSide(color: done ? const Color(0xFFDDE6DF) : _border),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? const Color(0xFFDEE8E1)
                          : const Color(0xFFF0F0F0),
                    ),
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 17,
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              lesson.title,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: done ? const Color(0xFF526357) : _ink,
                              ),
                            ),
                          ),
                        ),
                        if (failed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              done ? '오답 이력 · 복습 완료' : '3회 오답 · 다시 풀어보세요',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFB65A35),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (done)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 19, color: _green),
                          SizedBox(width: 5),
                          Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 11,
                              color: _green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (ongoing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2EF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 17,
                            color: _green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '학습 중',
                            style: TextStyle(
                              fontSize: 11,
                              color: _green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _StartPill(onTap: onTap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartPill extends StatelessWidget {
  const _StartPill({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AmbientMotion(
    builder: (context, t) => Material(
      color: _ink,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _StartSheen(t),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 17, color: Colors.white),
                SizedBox(width: 3),
                Text(
                  '시작',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StartSheen extends CustomPainter {
  const _StartSheen(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final x = (t * 3 - 1) * size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFDEEBE3).withValues(alpha: .22),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(x, 0, size.width * .5, size.height)),
    );
  }

  @override
  bool shouldRepaint(_StartSheen old) => old.t != t;
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 35, color: Colors.black38),
          SizedBox(height: 12),
          Text(
            '일치하는 학습 목록이 없어요.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          SizedBox(height: 6),
          Text(
            '다른 검색어로 찾아보세요.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    ),
  );
}

class _LearningNavigation extends StatelessWidget {
  const _LearningNavigation({required this.onHome});
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: InkWell(
                onTap: () {
                  if (i == 0) {
                    onHome();
                    return;
                  }
                  if (i == 1) return;
                  if (i == 2) {
                    Navigator.of(context)
                        .push<String>(
                          MaterialPageRoute(
                            builder: (_) => const ChallengesScreen(),
                          ),
                        )
                        .then((destination) {
                          if (context.mounted && destination == 'home') {
                            onHome();
                          }
                        });
                    return;
                  }
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('다음 화면은 준비 중이에요.')),
                    );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        [
                          Icons.home_outlined,
                          Icons.menu_book,
                          Icons.emoji_events_outlined,
                          Icons.person_outline,
                        ][i],
                        size: 25,
                        color: i == 1 ? _ink : Colors.grey,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ['홈', '학습하기', '도전과제', '마이페이지'][i],
                        style: TextStyle(
                          fontSize: 10,
                          color: i == 1 ? _ink : Colors.grey,
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
  );
}
