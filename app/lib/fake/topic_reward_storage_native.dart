import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async => File(
  '${(await getApplicationSupportDirectory()).path}/manners_prototype_topic_rewards_v1.json',
);
Future<String?> readTopicRewards() async {
  final f = await _file();
  return await f.exists() ? f.readAsString() : null;
}

Future<void> writeTopicRewards(String value) async {
  final f = await _file();
  await f.parent.create(recursive: true);
  final temporary = File('${f.path}.tmp');
  await temporary.writeAsString(value, flush: true);
  await temporary.rename(f.path);
}
