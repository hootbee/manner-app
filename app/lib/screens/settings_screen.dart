import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend.dart';
import 'welcome_screen.dart';
import 'partner_selection_screen.dart';

/// Account operations go through Backend; notification scheduling awaits its contract.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.includeWardrobeCoins = false,
    this.preview = false,
  });
  final bool includeWardrobeCoins;
  final bool preview;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _ink = Color(0xFF191D1A);
  static const privacyUrl =
      'https://github.com/hootbee/manner-app/blob/dev/docs/privacy/index.html';
  bool _busy = false;
  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _guestHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => WelcomeScreen(
          onStart: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PartnerSelectionScreen(preview: widget.preview),
            ),
          ),
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _delete() async {
    if (_busy || backend.account.value == null || !backend.online.value) return;
    setState(() => _busy = true);
    try {
      final confirmed = await _confirm(
        '회원 탈퇴',
        widget.includeWardrobeCoins
            ? '계정과 학습 기록, 보유한 코인이 모두 삭제되며 복구할 수 없습니다.'
            : '계정과 학습 기록이 모두 삭제되며 복구할 수 없습니다.',
        '탈퇴하기',
      );
      if (!mounted || !confirmed) return;
      if (backend.account.value == null) return;
      if (!backend.online.value) {
        _notice('연결된 뒤 다시 눌러 주세요');
        return;
      }
      final result = await backend.deleteAccount();
      if (!mounted) return;
      switch (result) {
        case DeleteResult.ok:
          _guestHome();
        case DeleteResult.offline:
          _notice('연결된 뒤 다시 눌러 주세요');
        case DeleteResult.failed:
          _notice('다시 로그인한 뒤 탈퇴해 주세요');
      }
    } catch (_) {
      if (mounted) _notice('다시 로그인한 뒤 탈퇴해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy || backend.account.value == null) return;
    setState(() => _busy = true);
    try {
      var result = await backend.signOut();
      if (!mounted) return;
      if (result is WouldLose) {
        final confirmed = await _confirm(
          '로그아웃',
          '기기에만 있는 기록 ${result.count}개가 사라져요',
          '로그아웃하기',
        );
        if (!mounted || !confirmed) return;
        result = await backend.signOut(discardUnsynced: true);
        if (!mounted) return;
      }
      if (result is SignedOut) _guestHome();
    } catch (_) {
      if (mounted) _notice('로그아웃하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _privacy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('개인정보 처리방침'),
      content: const SelectableText(privacyUrl),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: privacyUrl));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('주소 복사'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );

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
    appBar: AppBar(title: const Text('설정')),
    body: SafeArea(
      top: false,
      child: ValueListenableBuilder<Account?>(
        valueListenable: backend.account,
        builder: (context, account, _) => ValueListenableBuilder<bool>(
          valueListenable: backend.online,
          builder: (context, online, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _section(Icons.notifications_none_outlined, '알림 설정', [
                _row(
                  title: '학습 알림 받기',
                  subtitle: '준비 중',
                  trailing: const Switch(value: false, onChanged: null),
                ),
                _row(
                  key: const Key('notification-time'),
                  title: '알림 시간',
                  subtitle: '준비 중',
                  trailing: const Icon(Icons.lock_outline),
                ),
              ]),
              _section(Icons.person_outline, '계정 정보', [
                _row(
                  title: account?.email ?? '게스트',
                  trailing: const SizedBox.shrink(),
                ),
                if (account != null)
                  _row(
                    key: const Key('sign-out'),
                    title: '로그아웃',
                    onTap: _busy ? null : _signOut,
                  ),
              ]),
              _section(Icons.info_outline, '앱 정보', [
                _row(
                  title: '개인정보 처리방침',
                  icon: Icons.privacy_tip_outlined,
                  onTap: _privacy,
                ),
                _row(
                  title: '오픈소스 라이선스',
                  icon: Icons.description_outlined,
                  onTap: () =>
                      showLicensePage(context: context, applicationName: '매너스'),
                ),
              ]),
              if (_busy) const Center(child: Text('처리 중…')),
              if (account != null)
                Center(
                  child: TextButton(
                    key: const Key('delete-account'),
                    onPressed: _busy || !online ? null : _delete,
                    child: Text(online ? '회원 탈퇴' : '회원 탈퇴 (연결 필요)'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
