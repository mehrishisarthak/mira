import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:qyx/core/app_globals.dart';
import 'package:qyx/core/config/desktop_user_agent.dart';
import 'package:qyx/core/services/download_manager.dart';
import 'package:qyx/pages/mainscreen.dart';
import 'package:qyx/core/notifiers/theme_notifier.dart';
import 'package:qyx/pages/onboarding_screen.dart';
import 'package:qyx/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/core/services/secure_tab_store.dart';
import 'package:qyx/core/observers/provider_observer.dart';
import 'package:http/http.dart' as http;

import 'package:qyx/core/services/adblock_service.dart';
import 'package:qyx/core/services/adblock_ota_service.dart';
import 'package:qyx/core/config/hibernation_limits.dart';
import 'package:qyx/shell/browser/in_app_webview_engine.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warm the adblock rule cache OFF the first-frame path. The splash screen runs
  // for ~1.8s+ (wordmark animation + update check) before the first webview is
  // built, so this async load completes well before loadRulesSync() is read at
  // engine-creation time — without blocking the first frame on a 285KB decode
  // (which now also runs off-isolate via compute()).
  unawaited(() async {
    try {
      await AdBlockService.loadRules();
    } catch (e) {
      debugPrint('MIRA: AdBlock rule pre-warm failed: $e');
    }
  }());

  // 1. Initialize the Window Manager for PC platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    try {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden, 
      );

      // We don't await this to avoid blocking the main thread if the OS doesn't respond immediately
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint("MIRA: Window manager initialization failed: $e");
    }
  }

  // 2. Initialize Core Services (Prefs & Downloads)
  final prefs = await SharedPreferences.getInstance();
  // Load normal tabs from encrypted storage (migrating any legacy plaintext
  // list) so the rest of the app keeps its synchronous tab API (O-04). One
  // bounded Keystore read, well inside the splash buffer.
  final cachedTabs = await SecureTabStore.load(prefs);
  final PreferencesService preferencesService =
      PreferencesService(prefs, cachedTabs: cachedTabs);
  final isFirstRun = preferencesService.getFirstRun();

  await DownloadManager.init();
  await initHibernationLimits();

  final Widget home = SplashScreen(
    nextScreen: isFirstRun ? const OnboardingScreen() : const Mainscreen(),
  );

  // 3. Launch the App
  runApp(
    ProviderScope(
      observers: [const MiraProviderObserver()],
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
      child: MyApp(
        home: home,
        httpClient: null,
      ),
    ),
  );

  // Deferred to after the first frame: the cached UA is only consumed by the
  // mobile "request desktop site" toggle (off by default, applied live via
  // updateSettings), so it must not gate the first frame on a platform-channel
  // round-trip.
  unawaited(() async {
    try {
      final ua = await InAppWebViewEngine.fetchDefaultUserAgent();
      setCachedDesktopUserAgent(ua);
    } catch (e) {
      debugPrint('MIRA: Failed to fetch default user agent: $e');
    }
  }());

  // Fire-and-forget weekly tracker-list refresh. Lands on disk and applies at
  // next launch; must not block startup or touch live webviews.
  unawaited(AdBlockOtaService.maybeRefresh(preferencesService));
}

class MyApp extends ConsumerWidget {
  final Widget home;
  final http.Client? httpClient;

  const MyApp({super.key, required this.home, this.httpClient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);

    final lightTheme = ThemeData.light(useMaterial3: true).copyWith(
      primaryColor: appTheme.primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appTheme.primaryColor,
        brightness: Brightness.light,
        secondary: appTheme.accentColor,
      ),
      scaffoldBackgroundColor: appTheme.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appTheme.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: appTheme.primaryColor),
      ),
    );

    final darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      primaryColor: appTheme.primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appTheme.primaryColor,
        brightness: Brightness.dark,
        secondary: appTheme.accentColor,
      ),
      scaffoldBackgroundColor: appTheme.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appTheme.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: appTheme.primaryColor),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MIRA Browser',
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appTheme.mode,
      home: home,
    );
  }
}