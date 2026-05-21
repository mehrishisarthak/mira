import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/isar_database_repository.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/shell/browser/in_app_webview_engine.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';

/// Provider for the History Database Repository.
final historyRepositoryProvider = Provider<IsarHistoryRepository>((ref) {
  return IsarHistoryRepository();
});

/// Provider for the Bookmarks Database Repository.
final bookmarksRepositoryProvider = Provider<IsarBookmarkRepository>((ref) {
  return IsarBookmarkRepository();
});

/// Provider for a BrowserEngine instance. 
/// In a multi-tab environment, we typically have one engine per tab.
/// This factory provider creates an [InAppWebViewEngine] based on the tab's privacy state.
final browserEngineProvider = Provider.family<BrowserEngine, String>((ref, tabId) {
  final isGhost = ref.watch(isGhostModeProvider);
  final engine = InAppWebViewEngine(isPrivate: isGhost);
  
  ref.onDispose(() => engine.dispose());
  
  return engine;
});