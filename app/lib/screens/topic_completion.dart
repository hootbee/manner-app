import 'package:flutter/widgets.dart';
import '../backend.dart';
export '../backend.dart'
    show
        LearningEnd,
        TopicCompletionKind,
        TopicSetOutcome,
        TopicRewardConfig,
        CompletionProfile,
        TopicCompletionReceipt,
        TopicCompletionGateway;

class TopicCompletionBinding extends InheritedWidget {
  const TopicCompletionBinding({
    super.key,
    required this.gateway,
    required super.child,
  });
  final TopicCompletionGateway gateway;
  static TopicCompletionGateway? of(BuildContext c) =>
      c.getInheritedWidgetOfExactType<TopicCompletionBinding>()?.gateway;
  @override
  bool updateShouldNotify(TopicCompletionBinding oldWidget) =>
      gateway != oldWidget.gateway;
}
