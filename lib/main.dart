import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:mira/core/config/desktop_user_agent.dart';
import 'package:mira/core/services/download_manager.dart';
import 'package:mira/pages/mainscreen.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/onboarding_screen.dart';
import 'package:mira/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/core/observers/provider_observer.dart';
import 'package:http/http.dart' as http;

import 'package:mira/shell/browser/in_app_webview_engine.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Fetch Desktop User Agent for the underlying engine
  try {
    final ua = await InAppWebViewEngine.fetchDefaultUserAgent();
    setCachedDesktopUserAgent(ua);
  } catch (e) {
    debugPrint("MIRA: Failed to fetch default user agent: $e");
  }

  // 2. Initialize the Window Manager for PC platforms
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

  // 3. Initialize Core Services (Prefs & Downloads)
  final prefs = await SharedPreferences.getInstance();
  final PreferencesService preferencesService = PreferencesService(prefs);
  final isFirstRun = preferencesService.getFirstRun();

  await DownloadManager.init();

  final Widget home = SplashScreen(
    nextScreen: isFirstRun ? const OnboardingScreen() : const Mainscreen(),
  );

  // 4. Launch the App
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appTheme.mode,
      home: home,
    );
  }
}