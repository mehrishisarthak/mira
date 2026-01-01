import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/pages/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mira/model/caching/caching.dart'; 
import 'package:mira/pages/mainscreen.dart';
void main() async {
  // 1. Ensure Flutter bindings are ready for async code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SharedPreferences & Service
  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);
  
  // 3. Check Onboarding Status
  // (Uses the new method we added to PreferencesService)
  final isFirstRun = preferencesService.getFirstRun();

  // 4. Download Manager
  await DownloadManager.init();

  runApp(
    ProviderScope(
      // Inject the initialized service into the provider
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
      // Pass the correct starting screen based on first run status
      child: MyApp(
        startScreen: isFirstRun ? const OnboardingScreen() : const Mainscreen(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final Widget startScreen; 

  const MyApp({super.key, required this.startScreen});

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
      home: startScreen,
    );
  }
}