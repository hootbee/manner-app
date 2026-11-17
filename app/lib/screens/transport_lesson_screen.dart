import 'digital_questions.dart';
import 'digital_action_scene.dart';
import 'school_questions.dart';
import 'school_action_scene.dart';
import 'conversation_questions.dart';
import 'conversation_action_scene.dart';
import 'dining_questions.dart';
import 'dining_action_scene.dart';
import 'public_questions.dart';
import 'public_action_scene.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'partner_artwork.dart';
import 'partner_selection_screen.dart';
import 'transport_progress.dart';
import 'transport_questions.dart';

const _black = Color(0xFF222523),
    _green = Color(0xFF31815A),
    _red = Color(0xFFD84C50);

class TransportLessonScreen extends StatefulWidget {
  const TransportLessonScreen({
    super.key,
    required this.index,
    this.store,
    this.categoryId = 'transport',
  });
  final String categoryId;
  final int index;
  final TransportProgress? store;
  @override
  State<TransportLessonScreen> createState() => _TransportLessonScreenState();
}

class _TransportLessonScreenState extends State<TransportLessonScreen> {
  late int index = widget.index;
  TransportProgress get store => widget.store ?? TransportProgress.instance;
  bool get isPublic => widget.categoryId == 'public';
  bool get isDining => widget.categoryId == 'dining';
  bool get isConversation => widget.categoryId == 'conversation';
  bool get isDigital => widget.categoryId == 'digital';
  bool get isSchool => widget.categoryId == 'school-work';
  static const _categories = {
    'transport': ('대중교통 매너', transportQuestions),
    'public': ('공공장소 매너', publicQuestions),
    'dining': ('식사 매너', diningQuestions),
    'conversation': ('대화 매너', conversationQuestions),
    'digital': ('디지털 매너', digitalQuestions),
    'school-work': ('학교·직장 매너', schoolQuestions),
  };
  String get categoryTitle => _categories[widget.categoryId]!.$1;
  TransportQuestion get q => _categories[widget.categoryId]!.$2[index];
  QuestionSession get s => store.session(q.id);
  bool _wrong = false, _busy = false;
  int _reward = 0, _before = 0, _round = 0;
  void _retry() {
    setState(() {
      store.restart(q.id);
      _round++;
      _prepare();
    });
  }

  @override
  void initState() {
    super.initState();
    _prepare();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.changed();
    });
  }

  void _prepare() {
    if (s.phase == 'complete') store.restart(q.id);
    _wrong = s.lastCorrect == false;
    if (s.order.isEmpty && q.kind == QuestionKind.sequence) {
      s.order = List.generate(q.options.length, (i) => i);
    }
  }

  Future<void> _answer(bool correct, {String? selected}) async {
    if (_busy || s.solved) return;
    setState(() {
      store.submit(q, correct, selected: selected);
      _wrong = !correct;
    });
    await store.flush();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _before = store.xp;
      _reward = store.complete(q.id);
    });
    await store.flush();
    if (mounted) setState(() => _busy = false);
  }

  Widget _button(String label, VoidCallback? action, {bool white = false}) =>
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(
            backgroundColor: white ? Colors.white : _black,
            foregroundColor: white ? _black : Colors.white,
            side: white ? const BorderSide(color: Color(0xFFDDDDDD)) : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      );
  void _home() => Navigator.of(context).popUntil((r) => r.isFirst);
  void _next() {
    if (index == 9) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('마지막 문제입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      index++;
      _wrong = false;
      _reward = 0;
      _prepare();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (s.phase == 'complete') return _completion();
    final explanation = s.phase == 'explanation' || s.phase == 'review';
    final color = _wrong ? _red : _green;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '학습 목록으로 돌아가기',
                        onPressed: () async {
                          await store.flush();
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          categoryTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${(index + 1).toString().padLeft(2, '0')} / 10',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      10,
                      (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: i == index
                                ? _black
                                : const Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$categoryTitle · ${switch (q.kind) {
                                QuestionKind.choice => '선택형',
                                QuestionKind.touch => 'Touch 행동형',
                                QuestionKind.drag => 'Drag 행동형',
                                QuestionKind.sequence => '순서형',
                              }}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      q.scene,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if ((!isConversation &&
                                      q.kind == QuestionKind.sequence) ||
                                  q.kind == QuestionKind.choice) ...[
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 112,
                                  height: 108,
                                  child: _ReferenceArt(
                                    number: q.number,
                                    public: isPublic,
                                    dining: isDining,
                                    conversation: isConversation,
                                    school: isSchool,
                                    digital: isDigital,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const SizedBox(
                          width: 58,
                          height: 64,
                          child: PartnerArtwork(partner: MannerPartner.monkey),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: explanation
                                  ? color.withValues(alpha: .07)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: explanation
                                    ? color
                                    : const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Text(
                              explanation
                                  ? (_wrong
                                        ? '함께 정답을 확인해 봐요!'
                                        : '정답이에요! 멋진 배려예요!')
                                  : _wrong
                                  ? '조금 아쉬워요! ${q.hints[(s.hintLevel - 1).clamp(0, 2)]}'
                                  : isDigital
                                  ? '온라인에서도 서로를 배려해 볼까요?'
                                  : isSchool
                                  ? '함께 배우고 일하는 사람을 배려해 볼까요?'
                                  : isConversation
                                  ? '상대방의 마음을 생각하며 대화해 볼까요?'
                                  : isDining
                                  ? '함께 식사하는 사람의 입장도 생각해 볼까요?'
                                  : isPublic
                                  ? '함께 사용하는 사람의 입장도 생각해 볼까요?'
                                  : '함께 이동하는 승객의 입장도 생각해 볼까요?',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: explanation ? color : _black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: explanation ? color : _black,
                          child: Text(
                            explanation ? (_wrong ? '!' : 'O') : 'Q',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            explanation
                                ? (_wrong ? '정답 해설' : '정답이에요!')
                                : q.prompt,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_wrong &&
                        (q.kind == QuestionKind.sequence ||
                            q.kind == QuestionKind.drag))
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          key: const ValueKey('action-wrong-feedback'),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: .08),
                            border: Border.all(color: _red, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cancel, color: _red, size: 28),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  explanation
                                      ? '아직 정답이 아니에요. 해설을 확인하고 다시 풀어보세요.'
                                      : q.kind == QuestionKind.sequence
                                      ? '순서가 맞지 않아요. 카드를 다시 배열해 보세요.'
                                      : '알맞은 위치가 아니에요. 물건을 다시 옮겨 보세요.',
                                  style: const TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (q.kind == QuestionKind.touch) ...[
                      if (isDigital)
                        DigitalActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          answered: explanation,
                          success: explanation && !_wrong,
                          placements: s.placements,
                          onPlacement: (id, target) {
                            setState(
                              () =>
                                  s.placements = {...s.placements, id: target},
                            );
                            store.changed();
                          },
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        )
                      else if (isSchool)
                        SchoolActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          answered: explanation,
                          success: explanation && !_wrong,
                          placements: s.placements,
                          onPlacement: (id, target) {
                            setState(
                              () =>
                                  s.placements = {...s.placements, id: target},
                            );
                            store.changed();
                          },
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        )
                      else if (isConversation)
                        ConversationActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          answered: explanation,
                          success: explanation && !_wrong,
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        )
                      else if (isDining)
                        DiningActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          answered: explanation,
                          success: explanation && !_wrong,
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        )
                      else if (isPublic)
                        PublicActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          answered: explanation,
                          success: explanation && !_wrong,
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        )
                      else
                        _ActionScene(
                          key: ValueKey('${q.id}-$_round'),
                          number: q.number,
                          drag: false,
                          answered: explanation,
                          success: explanation && !_wrong,
                          onAnswer: (v) =>
                              _answer(v, selected: v ? 'target' : 'other'),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (explanation) ...[
                      if (q.kind == QuestionKind.drag && !_wrong) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: isDigital
                              ? DigitalActionScene(
                                  number: q.number,
                                  answered: true,
                                  success: true,
                                  placements: s.placements,
                                  onPlacement: (_, _) {},
                                  onAnswer: (_) {},
                                )
                              : isSchool
                              ? SchoolSceneArtwork(panel: q.number == 5 ? 4 : 5)
                              : isConversation
                              ? const ConversationSceneArtwork(panel: 3)
                              : isDining
                              ? DiningSceneArtwork(panel: q.number == 3 ? 3 : 4)
                              : isPublic
                              ? const PublicSceneArtwork(panel: 3)
                              : Image.asset(
                                  isPublic
                                      ? 'assets/public/action_scenes.webp'
                                      : 'assets/transport/drag_success.webp',
                                  key: const ValueKey('drag-success-scene'),
                                  fit: BoxFit.contain,
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_wrong)
                        Text(
                          '정답: ${q.kind == QuestionKind.choice
                              ? 'B'
                              : q.kind == QuestionKind.sequence
                              ? q.order.map((i) => q.options[i]).join(' → ')
                              : q.kind == QuestionKind.drag
                              ? (isDigital
                                    ? '개인 메신저와 연락처 창을 모두 닫기'
                                    : isSchool
                                    ? (q.number == 5 ? '개인 물건은 내 가방, 빈 컵은 정리함' : '내 출력물만 내 보관함에 넣기')
                                    : isConversation
                                    ? '휴대전화를 가방에 넣기'
                                    : isDining
                                    ? (q.number == 3 ? '공용 집게를 개인 접시로 옮기기' : '물병을 상대방 컵으로 옮기기')
                                    : isPublic
                                    ? '가방을 보관대에 넣기'
                                    : '가방을 몸 앞쪽으로 옮기기')
                              : isDigital
                              ? (q.number == 2 ? '배송 라벨의 개인정보 가리기' : '자물쇠 모양 화면 잠금')
                              : isSchool
                              ? '손들기로 발언 요청하기'
                              : isConversation
                              ? (q.number == 2 ? '상대의 말이 끝난 뒤 내 말풍선 누르기' : '휴대전화 화면 끄기')
                              : isDining
                              ? '휴지로 입과 코 가리기'
                              : q.number == 1
                              ? '자신의 좌석'
                              : isPublic
                              ? (q.number == 4 ? '무음 모드' : '옷소매 안쪽')
                              : '객차 안쪽 공간'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            height: 1.6,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        q.explanation,
                        style: const TextStyle(fontSize: 15, height: 1.7),
                      ),
                      const SizedBox(height: 22),
                      _button(
                        _wrong ? '다시 풀기' : '학습 완료',
                        _busy
                            ? null
                            : _wrong
                            ? _retry
                            : _finish,
                      ),
                    ] else if (q.kind == QuestionKind.choice) ...[
                      for (var i = 0; i < q.options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Material(
                            color: _wrong && s.selected == '$i'
                                ? _red.withValues(alpha: .07)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _wrong && s.selected == '$i'
                                    ? _red
                                    : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _answer(i == 1, selected: '$i'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFF0F0F0),
                                      child: Text(
                                        String.fromCharCode(65 + i),
                                        style: const TextStyle(
                                          color: _black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        q.options[i],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    if (_wrong && s.selected == '$i')
                                      const Icon(
                                        Icons.cancel,
                                        color: _red,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        '선택지를 누르면 바로 결과를 확인할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ] else if (q.kind == QuestionKind.sequence) ...[
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: s.order.length,
                        // Keep compatibility with the CI Flutter version's callback API.
                        // ignore: deprecated_member_use
                        onReorder: (old, next) {
                          setState(() {
                            if (next > old) next--;
                            final v = s.order.removeAt(old);
                            s.order.insert(next, v);
                            store.changed();
                          });
                        },
                        itemBuilder: (context, i) =>
                            ReorderableDragStartListener(
                              key: ValueKey(s.order[i]),
                              index: i,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: _wrong
                                      ? _red.withValues(alpha: .04)
                                      : Colors.white,
                                  border: Border.all(
                                    color: _wrong
                                        ? _red
                                        : const Color(0xFFDDDDDD),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFFF0F0F0),
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: _black,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        q.options[s.order[i]],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _button(
                        '정답 확인하기',
                        () => _answer(
                          List.generate(
                            s.order.length,
                            (i) => s.order[i] == q.order[i],
                          ).every((v) => v),
                        ),
                      ),
                    ] else if (q.kind == QuestionKind.drag) ...[
                      Container(
                        key: const ValueKey('drag-feedback-frame'),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _wrong ? _red : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            if (isDigital)
                              DigitalActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                answered: explanation,
                                success: explanation && !_wrong,
                                placements: s.placements,
                                onPlacement: (id, target) {
                                  setState(
                                    () => s.placements = {
                                      ...s.placements,
                                      id: target,
                                    },
                                  );
                                  store.changed();
                                },
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              )
                            else if (isSchool)
                              SchoolActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                answered: explanation,
                                success: explanation && !_wrong,
                                placements: s.placements,
                                onPlacement: (id, target) {
                                  setState(
                                    () => s.placements = {
                                      ...s.placements,
                                      id: target,
                                    },
                                  );
                                  store.changed();
                                },
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              )
                            else if (isConversation)
                              ConversationActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                answered: explanation,
                                success: explanation && !_wrong,
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              )
                            else if (isDining)
                              DiningActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                answered: false,
                                success: false,
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              )
                            else if (isPublic)
                              PublicActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                answered: false,
                                success: false,
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              )
                            else
                              _ActionScene(
                                key: ValueKey('${q.id}-$_round'),
                                number: q.number,
                                drag: q.kind == QuestionKind.drag,
                                onAnswer: (v) => _answer(
                                  v,
                                  selected: v ? 'target' : 'other',
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.kind == QuestionKind.drag
                            ? (isDigital
                                  ? '개인 창을 길게 누르고 닫기 영역으로 옮겨 보세요.'
                                  : isSchool
                                  ? '물건을 길게 누르고 알맞은 보관 위치로 옮겨 보세요.'
                                  : isConversation
                                  ? '휴대전화를 길게 누르고 가방 쪽으로 옮겨 보세요.'
                                  : isDining
                                  ? (q.number == 3
                                        ? '공용 집게를 길게 누르고 내 접시로 옮겨 보세요.'
                                        : '물병을 길게 누르고 상대방의 컵으로 옮겨 보세요.')
                                  : '가방을 길게 누르고 드래그해 보세요.')
                            : '그림 속 적절한 위치를 터치해 보세요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (store.storageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          store.storageError!,
                          style: const TextStyle(color: _red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completion() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AmbientMotion(
                builder: (context, t) => CustomPaint(painter: _Confetti(t)),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 260,
                    height: 165,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 20,
                          width: 105,
                          height: 140,
                          child: PartnerArtwork(partner: MannerPartner.cat),
                        ),
                        Positioned(
                          right: 0,
                          top: 20,
                          width: 105,
                          height: 140,
                          child: PartnerArtwork(partner: MannerPartner.monkey),
                        ),
                        Positioned(
                          left: 72,
                          top: 0,
                          width: 116,
                          height: 165,
                          child: PartnerArtwork(partner: MannerPartner.dog),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '매너 하나를 배웠어요!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '작은 배려로 더 좋은 일상에 가까워졌어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F4),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _reward == 0 ? '이미 경험치를 받은 학습이에요' : '획득한 총 경험치',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '+ $_reward XP',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('$index-$_before'),
                    tween: Tween(
                      begin: _before.toDouble(),
                      end: store.xp.toDouble(),
                    ),
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 1400,
                    ),
                    builder: (context, value, _) => Column(
                      children: [
                        Text(
                          'Lv. ${2 + value.round() ~/ 400} · ${value.round() % 400} / 400 XP',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (value % 400) / 400,
                            minHeight: 12,
                            color: _green,
                            backgroundColor: const Color(0xFFE4E6E4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: PrismaticButton(
                      label: '다음 문제 풀러가기',
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 4,
            child: IconButton(
              tooltip: '학습 목록으로 돌아가기',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            right: 8,
            top: 4,
            child: IconButton(
              tooltip: '홈으로 이동하기',
              icon: const Icon(Icons.home_outlined),
              onPressed: _home,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReferenceArt extends StatelessWidget {
  const _ReferenceArt({
    required this.number,
    this.public = false,
    this.dining = false,
    this.conversation = false,
    this.school = false,
    this.digital = false,
  });
  final bool public, dining, conversation, school, digital;
  final int number;
  @override
  Widget build(BuildContext context) {
    final category = digital
        ? 'digital'
        : school
        ? 'school-work'
        : conversation
        ? 'conversation'
        : dining
        ? 'dining'
        : public
        ? 'public'
        : 'transport';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/$category/question_$number.webp',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Interactive scene has no baked-in arrows, finger markers or highlighted answer.
class _ActionScene extends StatefulWidget {
  const _ActionScene({
    super.key,
    required this.number,
    required this.drag,
    required this.onAnswer,
    this.answered = false,
    this.success = false,
  });
  final int number;
  final bool drag;
  final bool answered, success;
  final ValueChanged<bool> onAnswer;
  @override
  State<_ActionScene> createState() => _ActionSceneState();
}

class _ActionSceneState extends State<_ActionScene> {
  Offset bag = const Offset(.32, .57);
  bool moving = false;
  Offset? touch;
  bool touchCorrect = false;
  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const ValueKey('action-scene'),
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.drag || widget.answered
                      ? null
                      : (d) {
                          final p = d.localPosition;
                          final correct = (widget.number == 1
                              ? Rect.fromLTWH(
                                  size.width * .02,
                                  size.height * .5,
                                  size.width * .3,
                                  size.height * .45,
                                ).contains(p)
                              : Rect.fromLTWH(
                                  size.width * .05,
                                  size.height * .2,
                                  size.width * .38,
                                  size.height * .65,
                                ).contains(p));
                          setState(() {
                            touch = Offset(
                              p.dx / size.width,
                              p.dy / size.height,
                            );
                            touchCorrect = correct;
                          });
                          widget.onAnswer(correct);
                        },
                  child: widget.success
                      ? _SuccessBackdrop(number: widget.number)
                      : _ActionBackdrop(number: widget.number),
                ),
              ),
              if (touch != null)
                Positioned(
                  left: (touch!.dx * size.width - 19).clamp(0, size.width - 38),
                  top: (touch!.dy * size.height - 19).clamp(
                    0,
                    size.height - 38,
                  ),
                  child: IgnorePointer(
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (touchCorrect ? _green : _red).withValues(
                          alpha: .9,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        touchCorrect ? 'O' : 'X',
                        key: const ValueKey('touch-result'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.drag)
                AnimatedPositioned(
                  duration: Duration(milliseconds: moving ? 0 : 300),
                  left: bag.dx * size.width,
                  top: bag.dy * size.height,
                  width: 60,
                  height: 72,
                  child: GestureDetector(
                    onLongPressStart: (_) => setState(() => moving = true),
                    onLongPressMoveUpdate: (d) => setState(
                      () => bag = Offset(
                        (.32 + d.offsetFromOrigin.dx / size.width).clamp(0, .8),
                        (.57 + d.offsetFromOrigin.dy / size.height).clamp(
                          0,
                          .7,
                        ),
                      ),
                    ),
                    onLongPressEnd: (_) {
                      final success = const Rect.fromLTWH(.62, .3, .32, .65)
                          .contains(
                            Offset(
                              bag.dx + 30 / size.width,
                              bag.dy + 36 / size.height,
                            ),
                          );
                      setState(() {
                        moving = false;
                        if (!success) bag = const Offset(.32, .57);
                      });
                      widget.onAnswer(success);
                    },
                    child: const Icon(Icons.backpack, size: 62, color: _black),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _ActionBackdrop extends StatelessWidget {
  const _ActionBackdrop({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 724,
      height: 724,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 2172,
          maxWidth: 2172,
          minHeight: 724,
          maxHeight: 724,
          child: Transform.translate(
            offset: Offset(
              -(number == 1
                      ? 0
                      : number == 5
                      ? 724
                      : 1448)
                  .toDouble(),
              0,
            ),
            child: Image.asset(
              'assets/transport/action_scenes.webp',
              width: 2172,
              height: 724,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Confetti extends CustomPainter {
  const _Confetti(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 34; i++) {
      final x = ((i * 73.3) % 100) / 100 * s.width;
      final y = ((t + i * .071) % 1) * s.height;
      c.save();
      c.translate(x, y);
      c.rotate(t * math.pi * 2 + i);
      c.drawRect(
        const Rect.fromLTWH(-2, -4, 4, 8),
        Paint()
          ..color = [
            const Color(0xFF466B58),
            const Color(0xFFBCA16B),
            const Color(0xFF444444),
          ][i % 3].withValues(alpha: .5),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}

class _SuccessBackdrop extends StatelessWidget {
  const _SuccessBackdrop({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 887,
      height: 887,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 1774,
          maxWidth: 1774,
          minHeight: 887,
          maxHeight: 887,
          child: Transform.translate(
            offset: Offset(number == 1 ? 0 : -887, 0),
            child: Image.asset(
              'assets/transport/touch_success.webp',
              width: 1774,
              height: 887,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}
