import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'lesson_explanation_content.dart';
import 'manners_learning_header.dart';
import 'partner_selection_screen.dart';

enum ExplanationAction { replay, next }

typedef ExplanationSourceOpener = Future<bool> Function(Uri url);

/// Reads presentation data and returns an intent; never changes learning records.
class LessonExplanationScreen extends StatefulWidget {
  const LessonExplanationScreen({
    super.key,
    required this.content,
    required this.partner,
    required this.progressHeader,
    this.hasNextProblem = false,
    this.answerRevealed = false,
    this.openSource,
    this.profileAsset,
    this.nextLabel = '다음 문제로 이동',
    this.shortDetails,
    this.inlineDetails = false,
  });
  final LessonExplanationContent content;
  final MannerPartner partner;
  final Widget progressHeader;
  final bool hasNextProblem, answerRevealed;
  final ExplanationSourceOpener? openSource;
  final String? profileAsset;
  final String nextLabel;
  final List<ExplanationReason>? shortDetails;
  final bool inlineDetails;
  @override
  State<LessonExplanationScreen> createState() =>
      _LessonExplanationScreenState();
}

class _LessonExplanationScreenState extends State<LessonExplanationScreen> {
  bool _expanded = false;
  static const _ink = Color(0xFF191D1A);
  static const _border = Color(0xFFE1E1E1);
  static const _bodyStyle = TextStyle(fontSize: 15, height: 1.5, color: _ink);
  LessonExplanationContent get data => widget.content;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    bottomNavigationBar: _footer(),
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        key: const Key('explanation-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MannersLearningHeader(),
            const SizedBox(height: 12),
            widget.progressHeader,
            const SizedBox(height: 28),
            if (widget.answerRevealed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '정답 확인 · 성공으로 기록되지 않아요.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            _card(
              key: const Key('explanation-core'),
              color: const Color(0xFFF3F3F3),
              children: [
                _heading('핵심 매너', Icons.check_circle),
                const SizedBox(height: 12),
                _educationText(
                  data.core,
                  style: _bodyStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (widget.inlineDetails)
              for (final section
                  in widget.shortDetails ?? <ExplanationReason>[]) ...[
                const SizedBox(height: 16),
                _card(
                  children: [
                    _heading(section.title, Icons.menu_book_outlined),
                    const SizedBox(height: 12),
                    _educationText(section.body),
                  ],
                ),
              ],
            if (widget.inlineDetails && data.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              _heading('근거 및 출처', Icons.link),
              const SizedBox(height: 12),
              for (var i = 0; i < data.sources.length; i++) ...[
                _sourceCard(data.sources[i], i),
                const SizedBox(height: 16),
              ],
              for (final section in data.extraSections)
                _card(
                  children: [
                    _heading(section.title, Icons.info_outline),
                    const SizedBox(height: 12),
                    _educationText(section.body),
                  ],
                ),
            ],
            SizedBox(height: widget.inlineDetails ? 16 : 28),
            _card(
              key: const Key('explanation-learning'),
              children: [
                _heading('학습 핵심', Icons.star_border_rounded),
                const SizedBox(height: 12),
                _educationText(data.learningCore),
                const Divider(height: 32, thickness: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        widget.profileAsset ?? _profile,
                        key: const Key('explanation-profile'),
                        width: 48,
                        height: 48,
                        cacheWidth: 192,
                        cacheHeight: 192,
                        fit: BoxFit.contain,
                        semanticLabel: widget.partner.name,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.practice,
                        key: const Key('explanation-practice'),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!widget.inlineDetails) ...[
              const SizedBox(height: 28),
              Semantics(
                button: true,
                expanded: _expanded,
                child: OutlinedButton(
                  key: const Key('explanation-toggle'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.all(16),
                    side: const BorderSide(color: _ink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _expanded ? '상세 해설 접기' : '자세한 해설 보기',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '행동의 이유 · 상황별 응용 · 근거 및 출처',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),
              if (MediaQuery.disableAnimationsOf(context))
                if (_expanded)
                  _details()
                else
                  const SizedBox(width: double.infinity)
              else
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? _details()
                      : const SizedBox(width: double.infinity),
                ),
            ],
          ],
        ),
      ),
    ),
  );

  String get _profile =>
      'assets/subway01/${switch (widget.partner) {
        MannerPartner.dog => 'dog',
        MannerPartner.cat => 'cat',
        MannerPartner.monkey => 'monkey',
      }}_thinking.png';

  Widget _heading(String title, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 26, color: _ink),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
    ],
  );

  Widget _card({
    Key? key,
    Color color = const Color(0xFFFAFAFA),
    required List<Widget> children,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _educationText(String text, {TextStyle style = _bodyStyle}) {
    final pieces = text.split('**');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < pieces.length; i++)
            TextSpan(
              text: pieces[i],
              style: i.isOdd
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w800,
      color: _ink,
    ),
  );

  Widget _details() => widget.shortDetails != null
      ? Column(
          key: const Key('explanation-details'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in widget.shortDetails!) ...[
              const SizedBox(height: 24),
              _sectionTitle(section.title),
              const SizedBox(height: 16),
              _educationText(section.body),
            ],
          ],
        )
      : Column(
          key: const Key('explanation-details'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _sectionTitle('왜 중요할까요?'),
            const SizedBox(height: 16),
            for (var i = 0; i < data.reasons.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFEDEDED),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.reasons[i].title,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _educationText(data.reasons[i].body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _sectionTitle('상황별 응용 및 주의사항'),
            const SizedBox(height: 16),
            for (var i = 0; i < data.faqs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: ValueKey('explanation-faq-$i'),
                      initiallyExpanded: data.faqsInitiallyExpanded,
                      maintainState: true,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      textColor: _ink,
                      collapsedTextColor: _ink,
                      iconColor: _ink,
                      collapsedIconColor: _ink,
                      title: Text(
                        'Q. ${data.faqs[i].question}',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _educationText(data.faqs[i].answer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            for (var i = 0; i < data.extraSections.length; i++) ...[
              _sectionTitle(data.extraSections[i].title),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: ValueKey('explanation-extra-$i'),
                child: _educationText(data.extraSections[i].body),
              ),
              const SizedBox(height: 28),
            ],
            _sectionTitle('근거 및 출처'),
            const SizedBox(height: 16),
            if (data.sourceIntro.isNotEmpty) ...[
              _educationText(data.sourceIntro),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < data.sources.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _sourceCard(data.sources[i], i),
              ),
            _educationText(
              data.disclaimer,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Colors.black54,
              ),
            ),
          ],
        );

  Widget _sourceCard(ExplanationSource source, int index) => Semantics(
    link: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('explanation-source-$index'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSource(source),
        child: _card(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '자료 ${index + 1}. ${source.title}',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.open_in_new, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(source.body, style: _bodyStyle),
            const SizedBox(height: 10),
            Text(
              '${source.agency} · ${source.date}\n${source.kind}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              source.url.toString(),
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: _ink,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openSource(ExplanationSource source) async {
    try {
      final opened =
          await (widget.openSource?.call(source.url) ?? launchUrl(source.url));
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자료를 열지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Widget _footer() => SafeArea(
    top: false,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('explanation-replay'),
                onPressed: () =>
                    Navigator.pop(context, ExplanationAction.replay),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('문제 다시 풀기', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('explanation-next'),
                onPressed: widget.hasNextProblem
                    ? () => Navigator.pop(context, ExplanationAction.next)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(widget.nextLabel, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
