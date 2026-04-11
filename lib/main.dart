import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/desktop/mira_window_args.dart';
import 'package:mira/core/desktop/private_standalone_window_provider.dart';
import 'package:mira/core/services/download_manager.dart';
import 'package:mira/shell/desktop/desktop_windowing.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/onboarding_screen.dart';
import 'package:mira/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/core/observers/provider_observer.dart';
import 'package:http/http.dart' as http;

import 'package:mira/core/config/desktop_user_agent.dart';
import 'package:mira/pages/mainscreen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set a custom user agent for desktop platforms to ensure websites render the desktop version.
  //checks if the app is runnig on desktop and if so, initializes the user agent string accordingly.
  //returned in form of UA string that mimics a common desktop browser, which can help ensure that websites render the desktop version of their content when accessed from the app.
  await initDesktopUserAgent();

  var isPrivateDesktopWindow = false;
  if (!kIsWeb) {
    try {
      final wc = await WindowController.fromCurrentEngine();
      isPrivateDesktopWindow = wc.arguments == kMiraPrivateWindowArgs;
    } catch (_) {
      // Tests, mobile, or engine not ready for multi-window.
    }
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    await desktopWindowManagerInit();
  }

  final prefs = await SharedPreferences.getInstance();
  final PreferencesService preferencesService = isPrivateDesktopWindow
      ? EphemeralTabPersistencePreferences(prefs)
      : PreferencesService(prefs);

  final isFirstRun =
      isPrivateDesktopWindow ? false : preferencesService.getFirstRun();

  await DownloadManager.init();

  final Widget home = isPrivateDesktopWindow
      ? const Mainscreen(isPrivateBrowserWindow: true)
      : SplashScreen(
          nextScreen:
              isFirstRun ? const OnboardingScreen() : const Mainscreen(),
        );

  runApp(
    ProviderScope(
      observers: [const MiraProviderObserver()],
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
        if (isPrivateDesktopWindow)
          privateStandaloneWindowProvider.overrideWith((ref) => true),
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
