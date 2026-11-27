import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'choice_lesson_screen.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';

/// Adapts the supplied v8 schema; grading stays in the shared choice state.
Future<ChoiceLessonData> loadApplication03() async {
  const root = 'assets/application03/';
  final raw = await Future.wait([
    for (final name in [
      'asset_rules',
      'problem_choice_transit03',
      'state_asset_mapping',
    ])
      rootBundle.loadString('${root}spec/$name.json'),
    rootBundle.loadString('${root}content/education_content_transit03.md'),
  ]);
  final art = jsonDecode(raw[0]) as Map<String, dynamic>,
      p = jsonDecode(raw[1]) as Map<String, dynamic>,
      mapping = jsonDecode(raw[2]) as Map<String, dynamic>;
  if (p['interaction']['evaluate_on_selection'] != false ||
      mapping['choice_evaluation_at'] != 'submit_click' ||
      (p['choices'] as List).singleWhere((c) => c['correct'] == true)['id'] !=
          p['correct_choice_id']) {
    throw FormatException('Inconsistent choice rules');
  }
  final assets = art['runtime_assets'],
      foot = art['foot_anchors_scene_px']['dangdang'];
  final scene = <String, dynamic>{
    'canvasSize': art['coordinate_system']['scene_canvas_px'],
    'sceneKey': 'application03-scene',
    'background': assets['background'],
    'staticCharacter': mapping['runtime_reuse_all_visual_states'],
    'sceneDescription': '임산부 배려석에 앉은 승객과 의아해하는 옆 승객의 상황.',
    'footAnchor': foot,
    'initialBodyHeight': 1,
    'layersBeforeHero': [
      assets['passengers']['seated'],
      assets['passengers']['bystander'],
    ],
    'layersAfterHero': [
      assets['effects']['bystander_reaction'],
      assets['effects']['hero_reaction'],
    ],
    'speechBubble': art['speech_bubble_flutter_widget'],
    'profiles': {
      for (final name in ['dog', 'cat', 'monkey'])
        name: 'assets/subway01/${name}_thinking.png',
    },
    'characters': {
      for (final pair in {
        'dog': 'dangdang',
        'cat': 'nyangnyang',
        'monkey': 'mongmong',
      }.entries)
        pair.key: {
          'referenceBodyHeight': 1,
          'referenceFeetWidth': 1,
          'poses': {
            for (final pose in ['tired', 'thinking', 'positive'])
              pose: {
                'asset': assets['hero'][pair.value],
                'sourceFeetWidth': 1,
                'sourceFoot': art['foot_anchors_scene_px'][pair.value],
                'sourceSize': art['coordinate_system']['scene_canvas_px'],
                'alphaBounds': [
                  0,
                  0,
                  ...art['coordinate_system']['scene_canvas_px'],
                ],
              },
          },
        },
    },
  };
  return ChoiceLessonData(
    {
      'problem_id': p['problem_id'],
      'title': p['title'],
      'situation': (p['situation'] as List).join('\n'),
      'instruction': p['instruction'],
      'choices': p['choices'],
      'correct_choice_id': p['correct_choice_id'],
      'feedback': {for (final c in p['choices']) c['id']: c['feedback']},
      'hints': [
        for (final id in ['hint_1', 'hint_2']) {'text': p['hint_content'][id]},
      ],
      'attempts': {
        'max_valid_submissions': p['interaction']['max_valid_submissions'],
      },
    },
    application03Education(raw[3], p),
    scene,
  );
}

/// Preserve the supplied educational paragraphs; approval metadata stays in reports.
Map<String, dynamic> application03Education(
  String markdown,
  Map<String, dynamic> problem,
) {
  final md = markdown.replaceAll('\r\n', '\n');
  String section(String title) => RegExp(
    '^#{2,3} ${RegExp.escape(title)}'
    r'\n+([\s\S]*?)(?=^#{2,3} |(?![\s\S]))',
    multiLine: true,
  ).firstMatch(md)!.group(1)!.trim();
  final reasons = RegExp(
    r'^\d+\. \*\*(.*?)\*\* (.+)$',
    multiLine: true,
  ).allMatches(section('왜 중요한가요? — 이유 3개'));
  final faqs = RegExp(
    r'\*\*Q\d+\. (.*?)\*\*\s*\nA\. ([\s\S]*?)(?=\n\s*\n\*\*Q|$)',
  ).allMatches(section('상황별 응용 및 Q&A — 3개'));
  final sourceLines = section(
    '확인한 공식 자료',
  ).split('\n').where((s) => RegExp(r'^\d+\. ').hasMatch(s));
  final sources = <Map<String, dynamic>>[];
  for (final line in sourceLines) {
    final m = RegExp(
      r'^\d+\. (.*?), \*\*(.*?)\*\*, (.*?)\. (https?://\S+) — (.*)$',
    ).firstMatch(line)!;
    sources.add({
      'agency': m[1],
      'title': m[2],
      'date': m[3],
      'url': m[4],
      'body': m[5],
      'kind': '제도 안내 및 권장 예절 참고 자료',
    });
  }
  final disclaimer = md
      .split('\n')
      .firstWhere((s) => s.startsWith('> '))
      .substring(2)
      .replaceAll(' 이 문서 전체는 최종 승인 전 초안입니다.', '');
  final result = <String, dynamic>{
    'problemId': problem['problem_id'],
    'core': section('핵심 매너'),
    'learningCore': section('학습 핵심'),
    'practice': section('선택 캐릭터 한마디'),
    'reasons': [
      for (final m in reasons) {'title': m[1], 'body': m[2]},
    ],
    'faqs': [
      for (final m in faqs) {'question': m[1], 'answer': m[2]!.trim()},
    ],
    'extraSections': [
      {'title': '권장 예절과 법적 의무의 구분', 'body': section('권장 예절과 법적 의무의 구분')},
    ],
    'sources': sources,
    'disclaimer': disclaimer,
  };
  if ((result['reasons'] as List).length != 3 ||
      (result['faqs'] as List).length != 3 ||
      sources.length != 3) {
    throw FormatException('Incomplete educational draft');
  }
  return result;
}

class Application03Screen extends StatelessWidget {
  const Application03Screen({
    super.key,
    required this.partner,
    this.playSound,
    this.soundMuted = false,
    this.hasNextProblem = false,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted, hasNextProblem;
  @override
  Widget build(BuildContext context) => ChoiceLessonScreen(
    partner: partner,
    playSound: playSound,
    soundMuted: soundMuted,
    number: 3,
    assetRoot: 'assets/application03/',
    keyPrefix: 'application03',
    application: true,
    dataLoader: loadApplication03,
    onNextProblem: hasNextProblem
        ? () => Navigator.of(context).pop(true)
        : null,
  );
}
