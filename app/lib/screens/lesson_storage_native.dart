import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> readLessons() async {
  final file = File(
    '${(await getApplicationSupportDirectory()).path}/manners_prototype_lessons.json',
  );
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeLessons(String value) async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final file = File('${dir.path}/manners_prototype_lessons.json');
  await file.writeAsString(value, flush: true);
}
