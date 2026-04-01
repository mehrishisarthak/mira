import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages which tabs are currently 'awake' in memory.
/// This decouples LRU logic from the BrowserView UI.
class HibernationNotifier extends StateNotifier<Set<String>> {
  static const int _maxAliveTabs = 3;
  
  // Use a LinkedHashSet to track order (oldest first)
  final LinkedHashSet<String> _mruSet = LinkedHashSet<String>();

  HibernationNotifier() : super({});

  void wakeTab(String tabId) {
    _mruSet.remove(tabId);
    _mruSet.add(tabId);

    while (_mruSet.length > _maxAliveTabs) {
      _mruSet.remove(_mruSet.first);
    }

    state = Set.from(_mruSet);
  }

  void onTabsClosed(Set<String> currentTabIds) {
    _mruSet.removeWhere((id) => !currentTabIds.contains(id));
    state = Set.from(_mruSet);
  }
}

final hibernationProvider = StateNotifierProvider<HibernationNotifier, Set<String>>((ref) {
  return HibernationNotifier();
});
