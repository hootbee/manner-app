import 'dart:js_interop';

@JS('localStorage.getItem')
external JSString? _get(JSString key);
@JS('localStorage.setItem')
external void _set(JSString key, JSString value);
Future<String?> readLessons() async =>
    _get('manners_prototype_lessons_v1'.toJS)?.toDart;
Future<void> writeLessons(String value) async =>
    _set('manners_prototype_lessons_v1'.toJS, value.toJS);
