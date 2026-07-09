import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/isar_database_repository.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/services/adblock_service.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/shell/browser/in_app_webview_engine.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:flutter/material.dart';

/// Provider for the History Database Repository.
final historyRepositoryProvider = Provider<IsarHistoryRepository>((ref) {
  return IsarHistoryRepository();
});

/// Provider for the Bookmarks Database Repository.
final bookmarksRepositoryProvider = Provider<IsarBookmarkRepository>((ref) {
  return IsarBookmarkRepository();
});

BrowserEngine? globalPreWarmedEngine;

/// Provider for a BrowserEngine instance.
/// In a multi-tab environment, we typically have one engine per tab.
/// This factory provider creates an [InAppWebViewEngine] based on the tab's privacy state.
final browserEngineProvider = Provider.family<BrowserEngine, String>((ref, tabId) {
  // Snapshot privacy at construction time — do NOT watch ghostTabsProvider.
  // Watching would rebuild the provider (disposing the engine) whenever any
  // ghost tab is added or removed, creating an orphaned non-private engine
  // for a tab that no longer exists.
  final isGhostTab = ref.read(ghostTabsProvider).tabs.any((t) => t.id == tabId);

  // Use loadRulesSync() — not adBlockRulesProvider.valueOrNull.
  // main.dart warms this cache OFF the critical path (unawaited). The always-on
  // splash buffer (~1.8s+ of animation + update check before the first webview
  // is built) guarantees the load finishes before this read. If the splash is
  // ever shortened/removed, re-verify this still holds — otherwise the first
  // page loads ad-block-off until a reload.
  final security = ref.read(securityProvider);
  final adBlockRules = security.isAdBlockEnabled
      ? AdBlockService.loadRulesSync()
      : const <AdBlockRule>[];

  if (globalPreWarmedEngine != null && !isGhostTab) {
    final preWarmed = globalPreWarmedEngine!;
    globalPreWarmedEngine = null;
    
    // Ensure the pre-warmed engine gets the latest settings.
    final theme = ref.read(themeProvider);
    preWarmed.updateSettings(BrowserEngineConfig(
      isDesktopMode: security.isDesktopMode,
      isDarkMode: theme.mode == ThemeMode.dark,
      isCameraBlocked: security.isCameraBlocked,
      isLocationBlocked: security.isLocationBlocked,
      adBlockRules: adBlockRules,
    ));
    
    ref.onDispose(() => preWarmed.dispose());
    return preWarmed;
  }

  final engine = InAppWebViewEngine(
    isPrivate: isGhostTab,
    adBlockRules: adBlockRules,
  );

  ref.onDispose(() => engine.dispose());
  return engine;
});
