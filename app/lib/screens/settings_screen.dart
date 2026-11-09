import 'package:flutter/material.dart';

/// Settings layout preview. Values live only while this route is open.
/// No notification scheduling, account mutations, or persistence occurs here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.accountEmail});
  final String? accountEmail;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  static const _ink = Color(0xFF191D1A);
  String get _timeLabel {
    final period = _time.hour < 12 ? '오전' : '오후';
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    return '$period $hour:${_time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '알림 시간',
      cancelText: '취소',
      confirmText: '확인',
      hourLabelText: '시',
      minuteLabelText: '분',
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _ink)),
        child: child!,
      ),
    );
    if (mounted && selected != null) setState(() => _time = selected);
  }

  Future<void> _info(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Text(message, style: const TextStyle(fontSize: 14, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  Future<void> _deletePreview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 20),
            SizedBox(width: 7),
            Text(
              '회원 탈퇴',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '정말로 탈퇴하시겠습니까?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              '지금까지의 학습 기록, 보유한 코인과 배지가\n모두 삭제되며 복구할 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEEEEEE),
                    foregroundColor: _ink,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('탈퇴하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회원 탈퇴는 계정 연결 후 사용할 수 있어요.')));
  }

  Widget _section(IconData icon, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: Color(0xFFE9EAEA)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                color: const Color(0xFFF0F1F0),
                child: Row(
                  children: [
                    Icon(icon, size: 23, color: _ink),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Color(0xFFF0F0F0),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      );
  Widget _row({
    required String title,
    IconData? icon,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Key? key,
  }) => ListTile(
    key: key,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    minLeadingWidth: 22,
    leading: icon == null ? null : Icon(icon, size: 23, color: _ink),
    title: Text(title, style: const TextStyle(fontSize: 14, color: _ink)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
    trailing: trailing ?? const Icon(Icons.chevron_right, size: 21),
    onTap: onTap,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF9F9F9),
      title: const Text(
        '설정',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _section(Icons.notifications_none_outlined, '알림 설정', [
            _row(
              title: '학습 알림 받기',
              trailing: Switch(
                value: _notifications,
                activeTrackColor: _ink,
                activeThumbColor: Colors.white,
                onChanged: (enabled) =>
                    setState(() => _notifications = enabled),
              ),
            ),
            _row(
              key: const Key('notification-time'),
              title: '알림 시간',
              onTap: _notifications ? _selectTime : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: _notifications ? _ink : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 21,
                    color: _notifications ? _ink : Colors.black26,
                  ),
                ],
              ),
            ),
          ]),
          _section(Icons.person_outline, '계정 정보', [
            _row(
              title: '로그인 계정',
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 155),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.accountEmail ?? '게스트',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 21),
                  ],
                ),
              ),
              onTap: () => _info('로그인 계정', '로그인 계정 정보는 추후 연결할 예정이에요.'),
            ),
            _row(
              icon: Icons.pets_outlined,
              title: '캐릭터 변경',
              subtitle: '다른 매너 파트너로 변경해요.',
              onTap: () => _info('캐릭터 변경', '파트너 변경 기능은 추후 연결할 예정이에요.'),
            ),
          ]),
          _section(Icons.info_outline, '앱 정보', [
            _row(
              icon: Icons.bug_report_outlined,
              title: '오류 제보',
              subtitle: '앱 사용 중 불편한 점을 알려주세요.',
              onTap: () => _info('오류 제보', '오류 제보 기능은 추후 연결할 예정이에요.'),
            ),
            _row(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보 처리방침',
              onTap: () => _info('개인정보 처리방침', '정식 개인정보 처리방침은 추후 연결할 예정이에요.'),
            ),
            _row(
              icon: Icons.description_outlined,
              title: '오픈소스 라이선스',
              onTap: () =>
                  showLicensePage(context: context, applicationName: '매너스'),
            ),
          ]),
          Center(
            child: TextButton(
              onPressed: _deletePreview,
              style: TextButton.styleFrom(foregroundColor: Colors.black54),
              child: const Text('회원 탈퇴', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    ),
  );
}
