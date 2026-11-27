import 'dart:convert';
import '../backend.dart';

/// Local prototype adapter only. Not used by LiveBackend/main.dart.
/// The application injects its existing profile/level policy and isolated storage.
class PreviewTopicCompletion implements TopicCompletionGateway {
  PreviewTopicCompletion({
    required this.userId,
    required this.read,
    required this.write,
    required this.profile,
    required this.applyTotal,
  });
  final String userId;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final CompletionProfile Function() profile;
  final void Function(int) applyTotal;
  static Future<void>? _tail;
  Future<void> restore() {
    final task = (_tail ?? Future<void>.value()).then((_) async {
      final raw = await read();
      final ledger = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final total = ledger.entries
          .where((e) => e.key.startsWith('user:$userId:'))
          .fold<int>(0, (sum, e) => sum + (e.value['xp'] as int));
      applyTotal(total);
    });
    final settled = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    _tail = settled;
    settled.then((_) {
      if (identical(_tail, settled)) _tail = null;
    });
    return task;
  }

  @override
  Future<TopicCompletionReceipt> complete(
    TopicSetOutcome outcome,
    TopicRewardConfig config,
  ) {
    final request = (_tail ?? Future<void>.value()).then((_) async {
      if (!outcome.finished) {
        throw StateError('Both explanations must be acknowledged');
      }
      final raw = await read();
      final ledger = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final key = 'user:$userId:topic:${outcome.topicId}:first_completion';
      int total() => ledger.entries
          .where((e) => e.key.startsWith('user:$userId:'))
          .fold(0, (sum, e) => sum + (e.value['xp'] as int));
      applyTotal(total());
      final before = profile();
      if (ledger.containsKey(key)) {
        return TopicCompletionReceipt(
          kind: TopicCompletionKind.review,
          awarded: 0,
          before: before,
          after: before,
        );
      }
      final amount = outcome.direct ? config.direct : config.reveal;
      if (amount < 0) throw StateError('Negative reward configuration');
      ledger[key] = {
        'xp': amount,
        'firstCompletionAt': DateTime.now().toUtc().toIso8601String(),
        'basic': outcome.basic!.name,
        'application': outcome.application!.name,
      };
      await write(
        jsonEncode(ledger),
      ); // One storage commit, before profile mutation.
      applyTotal(total());
      return TopicCompletionReceipt(
        kind: outcome.direct
            ? TopicCompletionKind.firstDirect
            : TopicCompletionKind.firstReveal,
        awarded: amount,
        before: before,
        after: profile(),
      );
    });
    final settled = request.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = settled;
    settled.then((_) {
      if (identical(_tail, settled)) _tail = null;
    });
    return request;
  }
}
