import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/history_entity.dart';
import 'package:mira/core/services/preferences_service.dart';

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  final PreferencesService _prefsService;

  HistoryNotifier(this._prefsService) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final jsonList = _prefsService.getHistory();
    state = jsonList.map((str) => HistoryItem.fromJson(str)).toList();
  }

  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final cleanQuery = query.trim();
    
    final currentList = [...state];
    currentList.removeWhere((item) => item.text == cleanQuery);
    currentList.insert(0, HistoryItem(text: cleanQuery, timestamp: DateTime.now()));

    if (currentList.length > 50) currentList.removeLast();

    state = currentList;
    _saveToPrefs();
  }

  Future<void> removeFromHistory(HistoryItem item) async {
    final currentList = [...state];
    currentList.remove(item);
    state = currentList;
    _saveToPrefs();
  }

  Future<void> clearHistory() async {
    state = [];
    await _prefsService.clearHistory();
  }

  void _saveToPrefs() {
    final jsonList = state.map((item) => item.toJson()).toList();
    _prefsService.setHistory(jsonList);
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return HistoryNotifier(prefsService);
});
