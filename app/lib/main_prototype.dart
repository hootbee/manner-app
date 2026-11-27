import 'dart:async';
import 'screens/topic_completion.dart';
import 'fake/preview_topic_completion.dart';
import 'fake/topic_reward_storage.dart';
import 'screens/lesson_result_audio.dart';
import 'screens/common_result_popup.dart';
import 'backend.dart';
import 'screens/activity_preview.dart';
import 'screens/activity_screen.dart';
import 'fake/fake_backend.dart';
import 'screens/wardrobe_preview.dart';
import 'screens/wardrobe_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/welcome_screen.dart';
import 'screens/transport_progress.dart';
import 'screens/partner_selection_screen.dart';

/// UI preview: fake backend only; no login or live service initialization.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF8F8F8),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await TransportProgress.instance.load();
  runApp(
    ResultPopupAudioScope(
      play: playBundledResultSound,
      child: const MannersPrototype(),
    ),
  );
}

class MannersPrototype extends StatefulWidget {
  const MannersPrototype({super.key});
  @override
  State<MannersPrototype> createState() => _MannersPrototypeState();
}

class _MannersPrototypeState extends State<MannersPrototype> {
  final _wardrobe = WardrobePreview();
  final _activity = ActivityPreview();
  late final TopicCompletionGateway _topicRewards;
  @override
  void initState() {
    super.initState();
    backend = FakeBackend.preset(
      const String.fromEnvironment('FAKE', defaultValue: 'guest'),
    );
    final preview = backend as FakeBackend;
    _topicRewards = PreviewTopicCompletion(
      userId: 'prototype:${preview.account.value?.email ?? 'guest'}',
      read: readTopicRewards,
      write: writeTopicRewards,
      applyTotal: preview.setPreviewTopicXp,
      profile: () {
        final h = preview.home.value;
        // FakeBackend's existing 100-XP level policy. Live supplies its own snapshots.
        return CompletionProfile(
          totalXp: h.xp,
          level: h.level,
          levelXp: (h.levelProgress * 100).round(),
          levelMax: 100,
        );
      },
    );
    unawaited(
      (_topicRewards as PreviewTopicCompletion).restore().catchError((
        Object error,
      ) {
        debugPrint('Prototype reward restore failed: $error');
      }),
    );
  }

  @override
  void dispose() {
    _wardrobe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TopicCompletionBinding(
    gateway: _topicRewards,
    child: MaterialApp(
      title: '매너스',
      debugShowCheckedModeBanner: false,
      // Desktop browsers preview the same 360 x 780 mobile canvas.
      builder: (context, child) => ActivityBinding(
        days: _activity.days,
        today: _activity.today,
        attendanceStreak: 4,
        learningStreak: 7,
        totalLearningDays: 12,
        totalProblems: 48,
        rewardDay: 4,
        rewardCoins: 30,
        claimAutomaticPopup: _activity.claimAutomaticPopup,
        child: WardrobeBinding(
          state: _wardrobe.state,
          catalog: WardrobePreview.catalog,
          purchase: _wardrobe.purchase,
          equip: _wardrobe.equip,
          child: kIsWeb
              ? Center(child: SizedBox(width: 360, height: 780, child: child))
              : child!,
        ),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF191D1A)),
        fontFamily: 'Pretendard',
        splashFactory: InkRipple.splashFactory,
      ),
      home: const _WelcomeRoute(),
    ),
  );
}

class _WelcomeRoute extends StatelessWidget {
  const _WelcomeRoute();

  @override
  Widget build(BuildContext context) => WelcomeScreen(
    onStart: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PartnerSelectionScreen(preview: true),
      ),
    ),
  );
}
