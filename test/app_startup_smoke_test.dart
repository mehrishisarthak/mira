import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/main.dart';
import 'package:mira/model/caching/caching.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        return null;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders splash shell and transitions to next screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          nextScreen: Scaffold(
            body: Center(child: Text('Startup Target Screen')),
          ),
        ),
      ),
    );

    expect(find.text('M I R A'), findsOneWidget);
    expect(find.text('INITIALIZING...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();

    expect(find.text('Startup Target Screen'), findsOneWidget);
  });

  testWidgets('app shell boots and shows splash branding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(service),
        ],
        child: const MyApp(
          targetScreen: Scaffold(body: Center(child: Text('Target Screen'))),
        ),
      ),
    );

    expect(find.text('M I R A'), findsOneWidget);
    expect(find.text('INITIALIZING...'), findsOneWidget);

    // SplashScreen schedules async timers; advance past them so the test binding
    // does not report pending timers after dispose.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
  });
}
