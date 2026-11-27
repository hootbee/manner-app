import 'activity_screen.dart';

/// Preview fixtures only. No coins are granted and no real activity is stored.
class ActivityPreview {
  ActivityPreview({DateTime? now})
    : today = DateTime(
        now?.year ?? DateTime.now().year,
        now?.month ?? DateTime.now().month,
        now?.day ?? DateTime.now().day,
      );
  final DateTime today;
  DateTime? _lastPopup;
  bool claimAutomaticPopup() {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    if (_lastPopup == date) return false;
    _lastPopup = date;
    return true;
  }

  late final days = List<ActivityDay>.unmodifiable([
    for (var ago = 0; ago < 19; ago++)
      if (ago < 4 || ago % 3 != 1)
        ActivityDay(
          today.subtract(Duration(days: ago)),
          attended: true,
          problems: ago == 0
              ? 12
              : ago == 1
              ? 10
              : ago == 2
              ? 14
              : ago % 5 * 2,
          completed: ago < 3 || ago % 3 == 0,
        ),
  ]);
}
