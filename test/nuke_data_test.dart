import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/history_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/services/database_providers.dart';
import 'package:qyx/core/services/isar_database_repository.dart';
import 'package:qyx/core/services/isar_schemas.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the app-state half of "Nuke Data" (history / tabs / ghost tabs
/// / chrome state) against the real notifiers, via a fake history repository
/// so no Isar instance is required.
///
/// Scope note: the native cookie/site-storage/per-engine-cache clears added
/// alongside this (CookieManager, WebStorageManager, BrowserEngine.clearCache)
/// need a real flutter_inappwebview platform channel and aren't exercised
/// here — see the implementation plan's manual verification step for that
/// half ("visually confirm that Nuke Data operates cleanly...").
class _RecordingHistoryRepository extends IsarHistoryRepository {
  bool cleared = false;
  final List<({String url, String title})> upserts = [];

  @override
  Future<void> init() async {}

  @override
  Stream<List<HistoryItemSchema>> watchAll() =>
      Stream<List<HistoryItemSchema>>.empty();

  @override
  Future<void> upsertByUrl(
    String url,
    String title, {
    Duration dedupeWindow = const Duration(minutes: 30),
  }) async {
    upserts.add((url: url, title: title));
  }

  @override
  Future<void> clear() async {
    cleared = true;
    upserts.clear();
  }
}

Future<ProviderContainer> _makeContainer(
  _RecordingHistoryRepository repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
      historyRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Nuke clears history, resets chrome state, exits Ghost Mode, and resets '
      'both tab stores', () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);

    // ---- Seed state that a real session would have accumulated. ----
    await repo.upsertByUrl('https://example.com', 'Example');
    container.read(tabsProvider.notifier)
      ..addTab(url: 'https://example.com')
      ..addTab(url: 'https://dart.dev');
    container.read(ghostTabsProvider.notifier).addTab(
          url: 'https://ghost.example.com',
        );
    container.read(isGhostModeProvider.notifier).state = true;
    container.read(browserChromeProvider.notifier).setLoadingProgress(42);

    expect(repo.upserts, isNotEmpty);
    expect(container.read(tabsProvider).tabOrder.length, 3);
    expect(container.read(ghostTabsProvider).tabOrder.length, 1);
    expect(container.read(isGhostModeProvider), isTrue);

    // ---- Run the same app-state clearing sequence as mira_drawer.dart's
    // Nuke Data handler (minus the native cookie/storage/cache calls — see
    // class doc comment). ----
    await container.read(historyProvider.notifier).clearHistory();
    container.read(browserChromeProvider.notifier).resetSessionChrome();
    container.read(tabsProvider.notifier).nuke();
    container.read(ghostTabsProvider.notifier).nuke();
    container.read(isGhostModeProvider.notifier).state = false;

    // ---- History: repository was cleared, nothing left to upsert-replay. ----
    expect(repo.cleared, isTrue);
    expect(repo.upserts, isEmpty);

    // ---- Normal tabs: reset to exactly one blank seed tab, not zero. ----
    final tabsState = container.read(tabsProvider);
    expect(tabsState.tabOrder.length, 1);
    expect(tabsState.safeActiveTab?.url, '');
    expect(tabsState.activeIndex, 0);

    // ---- Ghost tabs: fully emptied, no seed tab retained. ----
    final ghostState = container.read(ghostTabsProvider);
    expect(ghostState.tabOrder, isEmpty);
    expect(ghostState.tabs, isEmpty);

    // ---- Ghost Mode itself is turned back off. ----
    expect(container.read(isGhostModeProvider), isFalse);

    // ---- Chrome/loading state was reset, not left at the pre-nuke value. ----
    expect(container.read(browserChromeProvider).loadingProgress, isNot(42));
  });

  test('Nuke is safe to run against an already-empty session', () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);

    await container.read(historyProvider.notifier).clearHistory();
    container.read(browserChromeProvider.notifier).resetSessionChrome();
    container.read(tabsProvider.notifier).nuke();
    container.read(ghostTabsProvider.notifier).nuke();
    container.read(isGhostModeProvider.notifier).state = false;

    expect(repo.cleared, isTrue);
    expect(container.read(tabsProvider).tabOrder.length, 1);
    expect(container.read(ghostTabsProvider).tabOrder, isEmpty);
  });
}
