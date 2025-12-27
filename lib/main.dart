import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import this
import 'package:mira/model/caching/caching.dart'; // Import your caching model
import 'package:mira/pages/mainscreen.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready for async code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MIRA Browser',
      // Using a darker theme to match your privacy aesthetic
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: Mainscreen(),
    );
  }
}