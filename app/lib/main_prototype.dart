import 'backend.dart';
import 'fake/fake_backend.dart';
import 'fake/wardrobe_preview.dart';
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
  runApp(const MannersPrototype());
}

class MannersPrototype extends StatefulWidget {
  const MannersPrototype({super.key});
  @override
  State<MannersPrototype> createState() => _MannersPrototypeState();
}

class _MannersPrototypeState extends State<MannersPrototype> {
  final _wardrobe = WardrobePreview();
  @override
  void initState() {
    super.initState();
    backend = FakeBackend.preset(
      const String.fromEnvironment('FAKE', defaultValue: 'guest'),
    );
  }

  @override
  void dispose() {
    _wardrobe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '매너스',
    debugShowCheckedModeBanner: false,
    // Desktop browsers preview the same 360 x 780 mobile canvas.
    builder: (context, child) => WardrobeBinding(
      state: _wardrobe.state,
      catalog: WardrobePreview.catalog,
      purchase: _wardrobe.purchase,
      equip: _wardrobe.equip,
      child: kIsWeb
          ? Center(child: SizedBox(width: 360, height: 780, child: child))
          : child!,
    ),
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
