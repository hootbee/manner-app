import 'package:flutter/material.dart';
import 'partner_artwork.dart';
import 'partner_selection_screen.dart';

class ActivityDay {
  const ActivityDay(
    this.date, {
    this.attended = false,
    this.problems = 0,
    this.completed = false,
  });
  final DateTime date;
  final bool attended, completed;
  final int problems;
}

/// Presentation contract for the prototype. Attendance/rewards are owned outside screens.
class ActivityBinding extends InheritedWidget {
  const ActivityBinding({
    super.key,
    required this.days,
    required this.today,
    required this.attendanceStreak,
    required this.learningStreak,
    required this.totalLearningDays,
    required this.totalProblems,
    required this.rewardDay,
    required this.rewardCoins,
    required this.claimAutomaticPopup,
    required super.child,
  });
  final List<ActivityDay> days;
  final DateTime today;
  final int attendanceStreak, learningStreak, totalLearningDays, totalProblems;
  final int rewardDay, rewardCoins;
  final bool Function() claimAutomaticPopup;
  static ActivityBinding? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActivityBinding>();
  @override
  bool updateShouldNotify(ActivityBinding oldWidget) =>
      days != oldWidget.days || today != oldWidget.today;
}

Future<void> showAttendance(BuildContext context, MannerPartner partner) async {
  final data = ActivityBinding.maybeOf(context);
  if (data == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '출석창 닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              SizedBox(height: 115, child: PartnerArtwork(partner: partner)),
              const SizedBox(height: 8),
              const Text(
                '오늘도 출석했어요!',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '연속 출석 ${data.attendanceStreak}일째예요. 내일도 만나요!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              _panel(
                Column(
                  children: [
                    _RewardDays(day: data.rewardDay),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFD69A32),
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '+ ${data.rewardCoins}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                shaded: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _ink = Color(0xFF191D1A);
Widget _panel(Widget child, {bool shaded = false}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: shaded ? const Color(0xFFF1F2F2) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFE7E8EA)),
  ),
  child: Material(color: Colors.transparent, child: child),
);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.partner});
  final MannerPartner partner;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool _monthly = false;
  int _weekOffset = 0, _monthOffset = 0;
  DateTime? _selected;
  ActivityDay? _record(ActivityBinding data, DateTime date) {
    for (final day in data.days) {
      if (DateUtils.isSameDay(day.date, date)) return day;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = ActivityBinding.maybeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          tooltip: '뒤로 가기',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '활동 기록',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: data == null
          ? const Center(child: Text('활동 기록을 준비 중이에요.'))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                _monthly ? 14 : 20,
                8,
                _monthly ? 14 : 20,
                24,
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      for (final monthly in [false, true])
                        Expanded(
                          child: Semantics(
                            selected: _monthly == monthly,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: _monthly == monthly
                                    ? _ink
                                    : Colors.transparent,
                                foregroundColor: _monthly == monthly
                                    ? Colors.white
                                    : Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => setState(() {
                                _monthly = monthly;
                                _selected = null;
                              }),
                              child: Text(
                                monthly ? '월간' : '주간',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_monthly) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          Icons.local_fire_department,
                          '연속 학습',
                          '${data.learningStreak}일',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metric(
                          Icons.event_available,
                          '연속 출석',
                          '${data.attendanceStreak}일',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _calendar(data),
                ] else ...[
                  _week(data),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _metric(
                          Icons.local_fire_department,
                          '연속 출석',
                          '${data.attendanceStreak}일',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _metric(
                          Icons.emoji_events,
                          '총 학습일수',
                          '${data.totalLearningDays}일',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _metric(
                          Icons.star,
                          '해결한 문제',
                          '${data.totalProblems}개',
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: _monthly ? 8 : 16),
                _reward(data),
                SizedBox(height: _monthly ? 10 : 18),
                const Text(
                  '최근 활동',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                _recent(data),
              ],
            ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => _monthly
      ? Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E8EA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 3,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1F1F1),
                ),
                child: Icon(icon, size: 29, color: Colors.black54),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12)),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      : _panel(
          Column(
            children: [
              Icon(icon, size: 25, color: _ink),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(fontSize: 10)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
  Widget _navigation(String title, VoidCallback previous, VoidCallback? next) =>
      Row(
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: '이전 기간',
            onPressed: previous,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: '다음 기간',
            onPressed: next,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      );
  Widget _week(ActivityBinding data) {
    final today = DateUtils.dateOnly(data.today);
    final monday = today.subtract(
      Duration(days: today.weekday - 1 - _weekOffset * 7),
    );
    return Column(
      children: [
        _navigation(
          '${monday.month}월 ${(monday.day - 1) ~/ 7 + 1}주차',
          () => setState(() => _weekOffset--),
          _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(7, (i) {
            final date = monday.add(Duration(days: i));
            final attended = _record(data, date)?.attended ?? false;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: attended ? _ink : Colors.transparent,
                      border: Border.all(
                        color: attended ? _ink : Colors.black26,
                      ),
                    ),
                    child: attended
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(['월', '화', '수', '목', '금', '토', '일'][i]),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _calendar(ActivityBinding data) {
    final month = DateTime(data.today.year, data.today.month + _monthOffset);
    final first = month.subtract(Duration(days: month.weekday % 7));
    final count =
        ((month.weekday % 7 +
                    DateUtils.getDaysInMonth(month.year, month.month)) /
                7)
            .ceil() *
        7;
    return _panel(
      Column(
        children: [
          _navigation(
            '${month.year}년 ${month.month}월',
            () => setState(() {
              _monthOffset--;
              _selected = null;
            }),
            _monthOffset < 0
                ? () => setState(() {
                    _monthOffset++;
                    _selected = null;
                  })
                : null,
          ),
          Row(
            children: [
              for (final label in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(child: Center(child: Text(label))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 30,
              ),
              itemBuilder: (context, i) {
                final date = first.add(Duration(days: i));
                final record = _record(data, date);
                final selected = DateUtils.isSameDay(
                  _selected ?? data.today,
                  date,
                );
                return InkWell(
                  onTap: () => setState(() => _selected = date),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(selected ? 9 : 0),
                      border: Border.all(
                        color: selected ? _ink : const Color(0xFFEDEDED),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            color: date.month == month.month
                                ? _ink
                                : Colors.black26,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (record?.attended ?? false)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(Icons.circle, size: 6),
                              ),
                            if (record?.completed ?? false)
                              const Icon(Icons.check, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('● 출석     ✓ 학습 완료', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _reward(ActivityBinding data) => _monthly
      ? _monthlyReward(data)
      : _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '이번 출석 보상판',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!_monthly)
                    SizedBox(
                      width: 68,
                      height: 70,
                      child: PartnerArtwork(partner: widget.partner),
                    )
                  else
                    const Icon(Icons.card_giftcard, size: 38),
                ],
              ),
              Text(
                '특별 보상까지 ${7 - data.rewardDay}번의 출석이 남았어요!',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (!_monthly) ...[
                _RewardDays(day: data.rewardDay),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Text(
                    '${data.rewardDay} / 7일차',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: data.rewardDay / 7,
                        minHeight: 10,
                        color: _ink,
                        backgroundColor: Colors.black12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          shaded: true,
        );
  Widget _monthlyReward(ActivityBinding data) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '이번 출석 보상판',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${data.rewardDay} / 7일차',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: data.rewardDay / 7,
                  minHeight: 12,
                  color: _ink,
                  backgroundColor: Colors.black12,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '특별 보상까지 ${7 - data.rewardDay}번의 출석이 남았어요!',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 49,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard,
            size: 36,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );

  Widget _recent(ActivityBinding data) {
    final days =
        data.days
            .where(
              (day) =>
                  _selected == null || DateUtils.isSameDay(day.date, _selected),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return _panel(
      days.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('이 날짜에는 활동 기록이 없어요.'),
            )
          : Column(
              children: [
                for (final day in days.take(3))
                  ListTile(
                    minTileHeight: _monthly ? 31 : null,
                    minVerticalPadding: _monthly ? 0 : 4,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: _monthly
                        ? Row(
                            children: [
                              SizedBox(
                                width: 65,
                                child: Text(
                                  '${day.date.month}월 ${day.date.day}일',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Text(
                                day.attended ? '● 출석 완료' : '출석 없음',
                                style: const TextStyle(fontSize: 10),
                              ),
                              if (day.problems > 0) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '|',
                                    style: TextStyle(color: Colors.black26),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '✓ 데일리 학습 ${day.problems}문제',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            '${day.date.month}월 ${day.date.day}일',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                    subtitle: _monthly
                        ? null
                        : Text(
                            '${day.attended ? '● 출석 완료' : '출석 기록 없음'}${day.problems > 0 ? '  ·  문제 해결 ${day.problems}개' : ''}',
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('${day.date.month}월 ${day.date.day}일 활동'),
                        content: Text(
                          '${day.attended ? '출석 완료' : '출석 기록 없음'}\n해결한 문제 ${day.problems}개\n${day.completed ? '데일리 학습 완료' : '데일리 학습 미완료'}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RewardDays extends StatelessWidget {
  const _RewardDays({required this.day});
  final int day;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      7,
      (i) => Expanded(
        child: Column(
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < day ? _ink : Colors.white,
                border: Border.all(color: Colors.black12),
              ),
              child: Icon(
                i < day
                    ? Icons.check
                    : i == 6
                    ? Icons.card_giftcard
                    : Icons.lock,
                color: i < day ? Colors.white : Colors.black38,
                size: 19,
              ),
            ),
            const SizedBox(height: 5),
            Text('${i + 1}일', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}
