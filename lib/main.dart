import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/theme_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mira/model/caching/caching.dart'; // Imports PreferencesService CLASS
import 'package:mira/pages/mainscreen.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready for async code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);
  // 3. Downlaod Manager
  await DownloadManager.init();

  runApp(
    ProviderScope(
      // 3. Inject the initialized service into the provider
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

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
      home: Mainscreen(),
    );
  }
}