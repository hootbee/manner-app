import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Legacy flow tests acknowledge the newly added modal before continuing.
/// Dedicated popup tests independently check timing, blocking and dismissal.
Future<void> dismissResultPopup(WidgetTester t) async {
  if (find.byKey(const Key('common-result-popup')).evaluate().isNotEmpty) {
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
  }
}

Future<void> tapAfterResult(WidgetTester t, Finder target) async {
  await dismissResultPopup(t);
  await t.tap(target);
}
