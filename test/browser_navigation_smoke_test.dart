import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/pages/tab_screen.dart';
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

    expect(find.text('TABS'), findsOneWidget);
    // Ghost/private section is omitted until the user starts a private session.
    expect(find.text('GHOST'), findsNothing);
    expect(find.byType(CustomScrollView), findsOneWidget);
    // The lone seed tab (empty url) shows the empty-state, not a tab row.
    expect(find.text('No open tabs'), findsOneWidget);
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

    final secondTabId = notifier.state.tabOrder[1];
    notifier.closeTab(secondTabId);
    expect(notifier.state.tabs.length, 2);
    expect(notifier.state.activeIndex, 0);

    notifier.nuke();
    expect(notifier.state.tabs.length, 1);
    expect(notifier.state.tabs[notifier.state.tabOrder.first]!.url, '');
    expect(notifier.state.activeIndex, 0);
  });
}





