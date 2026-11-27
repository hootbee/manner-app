import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/welcome_screen.dart';
import 'screens/transport_progress.dart';
import 'screens/partner_selection_screen.dart';

/// UI preview: deliberately starts without initializing the backend.
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
  runApp(const MannersPrototype());
}

class MannersPrototype extends StatelessWidget {
  const MannersPrototype({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '매너스',
    debugShowCheckedModeBanner: false,
    // Desktop browsers preview the same 360 x 780 mobile canvas.
    builder: kIsWeb
        ? (context, child) =>
              Center(child: SizedBox(width: 360, height: 780, child: child))
        : null,
    theme: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F8F8),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF191D1A)),
      fontFamily: 'sans-serif',
      splashFactory: InkRipple.splashFactory,
    ),
    home: const _WelcomeRoute(),
  );
}

class _WelcomeRoute extends StatelessWidget {
  const _WelcomeRoute();

  @override
  Widget build(BuildContext context) => WelcomeScreen(
    onStart: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PartnerSelectionScreen()),
    ),
  );
}
