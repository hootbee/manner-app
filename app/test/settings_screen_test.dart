import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/screens/settings_screen.dart';
import 'package:mannerfit/screens/welcome_screen.dart';

class PendingDelete extends FakeBackend {
  PendingDelete()
    : super(
        account: const Account(name: 'test', email: 'test@example.com'),
      );
  final result = Completer<DeleteResult>();
  int calls = 0;
  @override
  Future<DeleteResult> deleteAccount() {
    calls++;
    return result.future;
  }
}

void main() {
  setUp(() => backend = FakeBackend.preset('signedIn'));
  Future<void> mount(WidgetTester tester, {bool coins = false}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(includeWardrobeCoins: coins)),
    );
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('delete-account')));
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pump();
  }

  testWidgets('guest hides account actions and notifications are disabled', (
    tester,
  ) async {
    backend = FakeBackend();
    await mount(tester);
    expect(find.byKey(const Key('delete-account')), findsNothing);
    expect(find.byKey(const Key('sign-out')), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('캐릭터 변경'), findsNothing);
    expect(find.text('오류 제보'), findsNothing);
  });
  testWidgets('offline prevents deletion', (tester) async {
    backend = FakeBackend.preset('offline');
    await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('delete-account')));
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('delete-account')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('failed deletion keeps account and explains reauthentication', (
    tester,
  ) async {
    backend = FakeBackend.preset('deleteFails');
    await mount(tester);
    await confirmDelete(tester);
    await tester.pumpAndSettle();
    expect(backend.account.value, isNotNull);
    expect(find.text('다시 로그인한 뒤 탈퇴해 주세요'), findsOneWidget);
  });
  testWidgets('successful deletion clears account and previous routes', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('manner@example.com'), findsOneWidget);
    await confirmDelete(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(backend.account.value, isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(WelcomeScreen))).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pending deletion cannot be submitted twice', (tester) async {
    final pending = PendingDelete();
    backend = pending;
    await mount(tester);
    await confirmDelete(tester);
    await tester.pump();
    expect(pending.calls, 1);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('delete-account')))
          .onPressed,
      isNull,
    );
    pending.result.complete(DeleteResult.failed);
    await tester.pumpAndSettle();
  });
  testWidgets('offline result after submission keeps account', (tester) async {
    final pending = PendingDelete();
    backend = pending;
    await mount(tester);
    await confirmDelete(tester);
    pending.result.complete(DeleteResult.offline);
    await tester.pumpAndSettle();
    expect(find.text('연결된 뒤 다시 눌러 주세요'), findsOneWidget);
    expect(backend.account.value, isNotNull);
  });
  testWidgets('signout warns about unsynced records; cancel keeps account', (
    tester,
  ) async {
    backend = FakeBackend.preset('wouldLose');
    await mount(tester);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('기기에만 있는 기록 3개가 사라져요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(backend.account.value, isNotNull);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃하기'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(backend.account.value, isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('privacy address can be copied on a small screen', (
    tester,
  ) async {
    await mount(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.text('개인정보 처리방침'));
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('주소 복사'));
    await tester.pumpAndSettle();
    expect(copied, contains('/docs/privacy/index.html'));
  });
  testWidgets('coin deletion wording is restricted to wardrobe preview', (
    tester,
  ) async {
    await mount(tester, coins: true);
    await tester.ensureVisible(find.byKey(const Key('delete-account')));
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    expect(find.textContaining('보유한 코인'), findsOneWidget);
  });
}
