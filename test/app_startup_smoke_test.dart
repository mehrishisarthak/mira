import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/main.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/pages/splashscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

class MockHttpClient extends Mock implements http.Client {}

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
          httpClient: mockClient,
          nextScreen: const Scaffold(
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
          httpClient: mockClient,
          nextScreen: const Scaffold(
            body: Center(child: Text('Startup Target Screen')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();

    expect(find.text('REQUIRED UPDATE'), findsOneWidget);
    expect(find.text('UPDATE MIRA'), findsOneWidget);
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
          targetScreen: const Scaffold(body: Center(child: Text('Target Screen'))),
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

  test('preferencesServiceProvider throws StateError without override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(preferencesServiceProvider),
      throwsA(anyOf(isA<StateError>(), isA<AssertionError>())),
    );
  });
}

