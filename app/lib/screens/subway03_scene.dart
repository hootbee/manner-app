import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';
import 'manners_hint_bubble.dart';

enum Subway03Pose { tired, thinking, positive }

class Subway03SceneConfig {
  const Subway03SceneConfig(this.json, {this.root = 'assets/subway03/'});
  final Map<String, dynamic> json;
  final String root;
  bool get usesCompletedScenes => json['completedScenes'] != null;
  String completedScene(MannerPartner partner) =>
      '$root${json['completedScenes'][species(partner)]}';
  Size get canvas => json['canvasSize'] == null
      ? const Size(1536, 1024)
      : Size(
          (json['canvasSize'][0] as num).toDouble(),
          (json['canvasSize'][1] as num).toDouble(),
        );
  List<String> layers(String key) => [
    for (final path in json[key] ?? const []) '$root$path',
  ];
  String species(MannerPartner partner) => switch (partner) {
    MannerPartner.dog => 'dog',
    MannerPartner.cat => 'cat',
    MannerPartner.monkey => 'monkey',
  };
  String get background => '$root${json['background']}';
  String profile(MannerPartner p) {
    final path = json['profiles'][species(p)] as String;
    return path.startsWith('assets/') ? path : '$root$path';
  }

  Map sprite(MannerPartner p, Subway03Pose pose) =>
      json['characters'][species(p)]['poses'][pose.name];
  String asset(MannerPartner p, Subway03Pose pose) =>
      '$root${sprite(p, pose)['asset']}';
  double scale(MannerPartner p, Subway03Pose pose) {
    final group = json['characters'][species(p)];
    return (json['initialBodyHeight'] as num) /
        (group['referenceBodyHeight'] as num) *
        (group['referenceFeetWidth'] as num) /
        (sprite(p, pose)['sourceFeetWidth'] as num);
  }

  Offset get foot => Offset(
    (json['footAnchor'][0] as num).toDouble(),
    (json['footAnchor'][1] as num).toDouble(),
  );
  Rect rect(MannerPartner p, Subway03Pose pose) {
    final m = sprite(p, pose), k = scale(p, pose);
    return Rect.fromLTWH(
      foot.dx - (m['sourceFoot'][0] as num) * k,
      foot.dy - (m['sourceFoot'][1] as num) * k,
      (m['sourceSize'][0] as num) * k,
      (m['sourceSize'][1] as num) * k,
    );
  }

  Rect visibleBounds(MannerPartner p, Subway03Pose pose) {
    final r = rect(p, pose),
        b = sprite(p, pose)['alphaBounds'],
        k = scale(p, pose);
    return Rect.fromLTRB(
      r.left + (b[0] as num) * k,
      r.top + (b[1] as num) * k,
      r.left + (b[2] as num) * k,
      r.top + (b[3] as num) * k,
    );
  }

  Iterable<String> get allAssets sync* {
    if (usesCompletedScenes) {
      for (final p in MannerPartner.values) {
        yield completedScene(p);
        yield profile(p);
      }
      return;
    }
    yield background;
    yield* layers('layersBeforeHero');
    yield* layers('layersAfterHero');
    for (final p in MannerPartner.values) {
      for (final pose in Subway03Pose.values) {
        yield asset(p, pose);
      }
    }
  }
}

/// Shared fixed canvas: neither the background nor each sprite is cropped/scaled independently.
class Subway03SceneRenderer extends StatelessWidget {
  const Subway03SceneRenderer({
    super.key,
    required this.config,
    required this.partner,
    required this.pose,
  });
  final Subway03SceneConfig config;
  final MannerPartner partner;
  final Subway03Pose pose;
  @override
  Widget build(BuildContext context) {
    if (config.usesCompletedScenes) {
      return AspectRatio(
        aspectRatio: config.canvas.aspectRatio,
        child: Image.asset(
          config.completedScene(partner),
          key: Key(config.json['sceneKey'] ?? 'completed-choice-scene'),
          fit: BoxFit.contain,
          semanticLabel: '${partner.name} ${config.json['sceneDescription']}',
        ),
      );
    }
    final r = config.rect(partner, pose);
    return Semantics(
      image: true,
      label: config.json['staticCharacter'] == true
          ? '${config.json['sceneDescription']} ${partner.name}'
          : '${config.json['sceneDescription'] ?? '임산부 배려석은 비어 있고 일반 좌석은 모두 찬 지하철.'} ${partner.name} ${switch (pose) {
              Subway03Pose.tired => '피곤한 표정',
              Subway03Pose.thinking => '고민하는 표정',
              Subway03Pose.positive => '긍정적인 표정',
            }}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: config.canvas.aspectRatio,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              key: Key(config.json['sceneKey'] ?? 'subway03-scene'),
              width: config.canvas.width,
              height: config.canvas.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      config.background,
                      key: const Key('subway03-background'),
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  for (final path in config.layers('layersBeforeHero'))
                    Positioned.fill(
                      child: Image.asset(
                        path,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 200,
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: Stack(
                        key: ValueKey(
                          '${config.species(partner)}-${config.json['staticCharacter'] == true ? 'static' : pose.name}',
                        ),
                        children: [
                          Positioned.fromRect(
                            rect: r,
                            child: Image.asset(
                              config.asset(partner, pose),
                              key: const Key('subway03-protagonist'),
                              fit: BoxFit.fill,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final path in config.layers('layersAfterHero'))
                    Positioned.fill(
                      child: Image.asset(
                        path,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  if (config.json['speechBubble'] case final Map bubble)
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(
                        (bubble['body_rect_scene_px'][0] as num)
                            .toDouble()
                            .toDouble(),
                        (bubble['body_rect_scene_px'][1] as num)
                            .toDouble()
                            .toDouble(),
                        (bubble['body_rect_scene_px'][2] as num)
                            .toDouble()
                            .toDouble(),
                        (bubble['tail_tip_scene_px'][1] as num)
                                .toDouble()
                                .toDouble() +
                            3,
                      ),
                      child: MannersSceneSpeechBubble(
                        text: (bubble['text_line_breaks'] as List).join('\n'),
                        body: Rect.fromLTWH(
                          0,
                          0,
                          (bubble['body_rect_scene_px'][2] as num).toDouble() -
                              (bubble['body_rect_scene_px'][0] as num)
                                  .toDouble(),
                          (bubble['body_rect_scene_px'][3] as num).toDouble() -
                              (bubble['body_rect_scene_px'][1] as num)
                                  .toDouble(),
                        ),
                        tailTip: Offset(
                          (bubble['tail_tip_scene_px'][0] as num).toDouble() -
                              (bubble['body_rect_scene_px'][0] as num)
                                  .toDouble(),
                          (bubble['tail_tip_scene_px'][1] as num).toDouble() -
                              (bubble['body_rect_scene_px'][1] as num)
                                  .toDouble(),
                        ),
                        strokeWidth: (bubble['stroke_width_at_scene_px'] as num)
                            .toDouble(),
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
}
