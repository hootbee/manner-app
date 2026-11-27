import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'choice_lesson_screen.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';
import 'topic_completion.dart';
import 'topic_completion_screen.dart';

const application05Root = 'assets/application05/';

class Application05Data {
  const Application05Data(
    this.lesson,
    this.details,
    this.reveal,
    this.rewards,
    this.completionSpec,
  );
  final ChoiceLessonData lesson;
  final List<ExplanationReason> details;
  final String reveal;
  final TopicRewardConfig rewards;
  final Map<String, dynamic> completionSpec;
}

Future<Application05Data> loadApplication05() async {
  final strings = await Future.wait([
    for (final path in [
      'spec/problem_choice_transit05.json',
      'spec/state_asset_mapping.json',
      'spec/asset_rules.json',
      'content/explanation.json',
      'content/reward_policy.json',
    ])
      rootBundle.loadString('$application05Root$path'),
    rootBundle.loadString('assets/application01/completion_screen_spec.json'),
  ]);
  final problem = jsonDecode(strings[0]) as Map<String, dynamic>;
  final mapping = jsonDecode(strings[1]) as Map<String, dynamic>;
  final rules = jsonDecode(strings[2]) as Map<String, dynamic>;
  final education = jsonDecode(strings[3]) as Map<String, dynamic>;
  if (problem['hint']['content_status'] != 'APPROVED' ||
      problem['explanation']['content_status'] != 'APPROVED' ||
      education['content_status'] != 'APPROVED' ||
      problem['correct_choice_id'] != 'B' ||
      rules['scene_canvas_px']['width'] != 900 ||
      rules['scene_canvas_px']['height'] != 400) {
    throw const FormatException(
      'Application05 requires approved B handoff and education.',
    );
  }
  const ids = {'dog': 'dangdang', 'cat': 'nyangnyang', 'monkey': 'mongmong'};
  return Application05Data(
    ChoiceLessonData(
      {
        'problem_id': problem['problem_id'],
        'title': problem['title'],
        'situationByCharacter': {
          for (final id in ids.values)
            id: (problem['description']['template'] as String).replaceAll(
              '{characterName}',
              mapping['selected_character_name_map'][id],
            ),
        },
        'instruction': problem['instruction'],
        'choices': problem['choices'],
        'correct_choice_id': problem['correct_choice_id'],
        'feedback': problem['feedback'],
        'hints': [
          for (final text in problem['hint']['messages']) {'text': text},
        ],
        'attempts': {
          'max_valid_submissions': problem['grading']['max_valid_submissions'],
        },
      },
      education,
      {
        'canvasSize': [900, 400],
        'sceneKey': 'application05-scene',
        'sceneDescription': '포장한 피자를 들고 서울 시내버스에 타려는 장면',
        'completedScenes': {
          for (final entry in ids.entries)
            entry.key: mapping['selected_character_scene_map'][entry.value],
        },
        'profiles': {
          for (final species in ids.keys)
            species: 'assets/subway01/${species}_thinking.png',
        },
      },
    ),
    List.unmodifiable(
      (education['shortDetails'] as List).map(
        (s) => ExplanationReason(s['title'], s['body']),
      ),
    ),
    problem['answer_reveal'],
    TopicRewardConfig.fromJson(jsonDecode(strings[4])),
    jsonDecode(strings[5]),
  );
}

class Application05Screen extends StatefulWidget {
  const Application05Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.basicOutcome,
    this.playSound,
    this.soundMuted = false,
    this.hasNextProblem = false,
    this.openSource,
  });
  final MannerPartner partner;
  final LearningEnd? basicOutcome;
  final LessonSoundPlayer? playSound;
  final bool soundMuted, hasNextProblem;
  final ExplanationSourceOpener? openSource;
  @override
  State<Application05Screen> createState() => _Application05ScreenState();
}

class _Application05ScreenState extends State<Application05Screen> {
  late Future<Application05Data> _data = loadApplication05();
  bool _completing = false;
  Future<void> _complete(bool revealed, Application05Data data) async {
    if (_completing) return;
    final gateway = TopicCompletionBinding.of(context);
    if (gateway == null || widget.basicOutcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gateway == null
                ? '학습 완료 서비스를 연결해 주세요.'
                : '05번 기본 문제와 해설을 먼저 완료해 주세요.',
          ),
        ),
      );
      return;
    }
    _completing = true;
    final outcome = TopicSetOutcome(
      topicId: 'transit_05',
      basic: widget.basicOutcome,
      application: revealed
          ? LearningEnd.answerRevealed
          : LearningEnd.directCorrect,
    );
    try {
      final next = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (c) => TopicCompletionScreen(
            complete: () => gateway.complete(outcome, data.rewards),
            partner: widget.partner,
            topicTitle: LessonExplanationContent.fromJson(
              data.lesson.education,
            ).learningPlain,
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
  Widget build(BuildContext context) => FutureBuilder<Application05Data>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: TextButton(
              onPressed: () => setState(() => _data = loadApplication05()),
              child: const Text('자료를 불러오지 못했어요. 다시 불러오기'),
            ),
          ),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return ChoiceLessonScreen(
        key: ValueKey(widget.partner),
        partner: widget.partner,
        assetRoot: application05Root,
        keyPrefix: 'application05',
        number: 5,
        application: true,
        enhancedFeedback: true,
        dataLoader: () async => data.lesson,
        playSound: widget.playSound,
        soundMuted: widget.soundMuted,
        shortDetails: data.details,
        inlineExplanation: true,
        fitLongestHint: true,
        revealExplanation: data.reveal,
        onLearningComplete: (revealed) => _complete(revealed, data),
        openSource: widget.openSource,
      );
    },
  );
}
