import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'partner_selection_screen.dart';
import 'sequence_lesson_screen.dart';
import 'sequence_lesson_state.dart';
import 'lesson_explanation_content.dart';
import 'lesson_feedback_sound.dart';
import 'topic_completion.dart';
import 'topic_completion_screen.dart';

const _root = 'assets/application04/';

class Application04Data {
  const Application04Data(
    this.question,
    this.sceneAsset,
    this.education,
    this.details,
    this.reveal,
    this.rewards,
    this.completionSpec,
  );
  final SequenceQuestion question;
  final String sceneAsset;
  final LessonExplanationContent education;
  final List<ExplanationReason> details;
  final String reveal;
  final TopicRewardConfig rewards;
  final Map<String, dynamic> completionSpec;
}

/// User-approved multiple orders and copy, with the original B artwork intact.
Future<Application04Data> loadApplication04(MannerPartner partner) async {
  final raw = await Future.wait([
    rootBundle.loadString('${_root}spec/problem_sequence_transit04.json'),
    rootBundle.loadString('${_root}spec/state_asset_mapping.json'),
    rootBundle.loadString('${_root}spec/asset_rules.json'),
    rootBundle.loadString('${_root}content/explanation.json'),
    rootBundle.loadString('${_root}content/reward_policy.json'),
    rootBundle.loadString('assets/application01/completion_screen_spec.json'),
  ]);
  final problem = jsonDecode(raw[0]) as Map<String, dynamic>;
  final mapping = jsonDecode(raw[1]) as Map<String, dynamic>;
  final rules = jsonDecode(raw[2]) as Map<String, dynamic>;
  if (problem['grading']['status'] != 'APPROVED' ||
      problem['grading']['mode'] != 'multiple_accepted_orders' ||
      problem['education_content_status'] != 'APPROVED' ||
      rules['scene']['runtime_scene_canvas_px'].toString() != '[976, 397]') {
    throw const FormatException(
      'Application04 requires approved multiple-order data and B artwork.',
    );
  }
  final id = switch (partner) {
    MannerPartner.dog => 'dangdang',
    MannerPartner.cat => 'nyangnyang',
    MannerPartner.monkey => 'mongmong',
  };
  final name =
      problem['scenario_name_binding']['selected_character_ids'][id] as String;
  final scenario = (problem['scenario_name_binding']['template_lines'] as List)
      .cast<String>()
      .map((s) => s.replaceAll('{character_name}', name))
      .join('\n');
  final cards = problem['cards'] as Map<String, dynamic>;
  final initial = List<String>.from(problem['initial_order']);
  return Application04Data(
    SequenceQuestion.fromJson({
      'problemId': problem['id'],
      'title': problem['title'],
      'scenario': scenario,
      'instruction': problem['operation'],
      'gradingApproved': true,
      'correctOrder': problem['planning_recommended_order'],
      'acceptedOrders': problem['grading']['accepted_orders'],
      'initialOrder': initial,
      'cards': [
        for (final id in initial)
          {
            'id': id,
            'label': cards[id]['text'],
            'thumbnail': mapping['common_card_art'][id],
            'thumbnailAspectRatio':
                (cards[id]['sprite_size_px'][0] as num) /
                (cards[id]['sprite_size_px'][1] as num),
          },
      ],
      'hints': problem['hints'],
      'feedback': problem['feedback'],
      'maxValidSubmissions': problem['grading']['max_valid_submissions'],
    }),
    '$_root${mapping['scene_by_character'][id]}',
    LessonExplanationContent.fromJson(jsonDecode(raw[3])),
    List.unmodifiable(
      (jsonDecode(raw[3])['shortDetails'] as List).map(
        (s) => ExplanationReason(s['title'], s['body']),
      ),
    ),
    problem['feedback']['reveal'],
    TopicRewardConfig.fromJson(jsonDecode(raw[4])),
    jsonDecode(raw[5]),
  );
}

class Application04Screen extends StatefulWidget {
  const Application04Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.basicOutcome,
    this.playSound,
    this.soundMuted = false,
    this.hasNextProblem = false,
  });
  final MannerPartner partner;
  final LearningEnd? basicOutcome;
  final LessonSoundPlayer? playSound;
  final bool soundMuted, hasNextProblem;
  @override
  State<Application04Screen> createState() => _Application04ScreenState();
}

class _Application04ScreenState extends State<Application04Screen> {
  late Future<Application04Data> _data = loadApplication04(widget.partner);
  bool _completing = false;

  Future<void> _complete(
    SequenceLessonState state,
    Application04Data data,
  ) async {
    if (_completing || !(state.success || state.solutionRevealed)) return;
    final gateway = TopicCompletionBinding.of(context);
    if (gateway == null || widget.basicOutcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gateway == null
                ? '학습 완료 서비스를 연결해 주세요.'
                : '04번 기본 문제와 해설을 먼저 완료해 주세요.',
          ),
        ),
      );
      return;
    }
    _completing = true;
    final outcome = TopicSetOutcome(
      topicId: 'transit_04',
      basic: widget.basicOutcome,
      application: state.solutionRevealed
          ? LearningEnd.answerRevealed
          : LearningEnd.directCorrect,
    );
    try {
      final next = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (c) => TopicCompletionScreen(
            complete: () => gateway.complete(outcome, data.rewards),
            partner: widget.partner,
            topicTitle: data.education.learningCore,
            spec: data.completionSpec,
            onNext: widget.hasNextProblem
                ? () => Navigator.of(c).pop(true)
                : null,
          ),
        ),
      );
      if (mounted && next == true) Navigator.of(context).pop(true);
    } finally {
      _completing = false;
    }
  }

  @override
  void didUpdateWidget(covariant Application04Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partner != widget.partner) {
      _data = loadApplication04(widget.partner);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Application04Data>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: TextButton(
              onPressed: () =>
                  setState(() => _data = loadApplication04(widget.partner)),
              child: const Text('자료를 불러오지 못했어요. 다시 불러오기'),
            ),
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return SequenceLessonScreen(
        key: ValueKey(widget.partner),
        question: data.question,
        educationContent: data.education,
        shortDetails: data.details,
        inlineExplanation: true,
        onLearningComplete: (state) => _complete(state, data),
        revealExplanation: data.reveal,
        showRemainingAttempts: true,
        fitLongestHint: true,
        questionAsset: '',
        explanationAsset: '',
        assetPrefix: _root,
        sceneAsset: data.sceneAsset,
        sceneAspectRatio: 976 / 397,
        sceneLabel: '${widget.partner.name}가 내릴 정류장을 놓친 버스 장면',
        clipScene: false,
        number: 4,
        application: true,
        partner: widget.partner,
        playSound: widget.playSound,
        soundMuted: widget.soundMuted,
      );
    },
  );
}
