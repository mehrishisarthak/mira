import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/core/notifiers/search_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/pages/tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders browser tab navigation shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(preferencesService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TabsSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ACTIVE SESSIONS'), findsOneWidget);
    expect(find.text('GHOST PROTOCOL'), findsOneWidget);
    expect(find.byType(SliverGrid), findsNWidgets(2));
    expect(find.text('New Tab'), findsWidgets);
  });

  test('tabs notifier supports add/switch/close without index breakage',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = PreferencesService(prefs);
    final notifier = TabsNotifier(service);

    expect(notifier.state.tabs.length, 1);
    expect(notifier.state.activeIndex, 0);

    notifier.addTab(url: 'https://example.com');
    notifier.addTab(url: 'https://dart.dev');
    expect(notifier.state.tabs.length, 3);
    expect(notifier.state.activeIndex, 2);

    notifier.switchTab(0);
    expect(notifier.state.activeIndex, 0);

    final secondTabId = notifier.state.tabs[1].id;
    notifier.closeTab(secondTabId);
    expect(notifier.state.tabs.length, 2);
    expect(notifier.state.activeIndex, 0);

    notifier.nuke();
    expect(notifier.state.tabs.length, 1);
    expect(notifier.state.tabs.first.url, '');
    expect(notifier.state.activeIndex, 0);
  });
}

