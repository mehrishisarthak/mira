import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/main.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

/// Drives the splash frame-by-frame until it navigates away, so its mixed
/// Future.delayed timers + AnimationControllers all drain (no pending-timer
/// assertion at teardown).
Future<void> _drainSplash(WidgetTester tester) async {
  for (var i = 0; i < 40 && tester.any(find.byType(SplashScreen)); i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        return null;
      }
      return null;
    });
  });

  setUp(() {
    mockClient = MockHttpClient();
    PackageInfo.setMockInitialValues(
      appName: 'Mira',
      packageName: 'com.mira.browser',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Default mock response: No update needed
    when(() => mockClient.get(any())).thenAnswer((_) async => http.Response(
          json.encode({
            'minimum_version': '1.0.0',
            'latest_version': '1.0.0',
            'store_url': 'https://store.com',
          }),
          200,
        ));
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('renders splash shell and transitions to next screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          preWarmEngineFactory: () => null,
          httpClient: mockClient,
          nextScreen: const Scaffold(
            body: Center(child: Text('Startup Target Screen')),
          ),
        ),
      ),
    );

    // Splash renders the wordmark as individual animated letters.
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);

    await _drainSplash(tester);

    expect(find.text('Startup Target Screen'), findsOneWidget);
  });

  testWidgets('navigates to UpdateScreen on force update', (tester) async {
    when(() => mockClient.get(any())).thenAnswer((_) async => http.Response(
          json.encode({
            'minimum_version': '2.0.0',
            'latest_version': '2.0.0',
            'store_url': 'https://store.com',
          }),
          200,
        ));

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          preWarmEngineFactory: () => null,
          httpClient: mockClient,
          nextScreen: const Scaffold(
            body: Center(child: Text('Startup Target Screen')),
          ),
        ),
      ),
    );

    await _drainSplash(tester);

    expect(find.text('REQUIRED UPDATE'), findsOneWidget);
    expect(find.text('UPDATE QYX'), findsOneWidget);
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
        child: MyApp(
          httpClient: mockClient,
          home: SplashScreen(
          preWarmEngineFactory: () => null,
            httpClient: mockClient,
            nextScreen:
                const Scaffold(body: Center(child: Text('Target Screen'))),
          ),
        ),
      ),
    );

    // Splash renders the wordmark as individual animated letters.
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);

    await _drainSplash(tester);
  });

  test('preferencesServiceProvider throws StateError without override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(preferencesServiceProvider),
      throwsA(anyOf(isA<StateError>(), isA<AssertionError>())),
    );
  });
}

