import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/config/hibernation_limits.dart';

/// Manages which tabs are currently 'awake' in memory.
/// This decouples LRU logic from the BrowserView UI.
class HibernationNotifier extends StateNotifier<Set<String>> {
  // Use a LinkedHashSet to track order (oldest first)
  final LinkedHashSet<String> _mruSet = LinkedHashSet<String>();

  HibernationNotifier() : super({});

  void wakeTab(String tabId) {
    if (_mruSet.isNotEmpty && _mruSet.last == tabId) return;

    _mruSet.remove(tabId);
    _mruSet.add(tabId);

    final cap = maxAliveWebViewTabs();
    while (_mruSet.length > cap) {
      _mruSet.remove(_mruSet.first);
    }

    state = Set.from(_mruSet);
  }

  /// Evicts only the tabs that were actually closed.
  ///
  /// Takes the *closed* ids, not the surviving ones: `_mruSet` is a single
  /// global set spanning both the normal and ghost pools (the dual-mode stack
  /// mounts both at once), but each call site only knows about its own pool.
  /// Retaining by "not in currentTabIds" therefore evicted every awake tab of
  /// the *other* mode on any close.
  void onTabsClosed(Set<String> closedTabIds) {
    if (closedTabIds.isEmpty) return;
    _mruSet.removeAll(closedTabIds);
    state = Set.from(_mruSet);
  }
}

final hibernationProvider = StateNotifierProvider<HibernationNotifier, Set<String>>((ref) {
  return HibernationNotifier();
});
