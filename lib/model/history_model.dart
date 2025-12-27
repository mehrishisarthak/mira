import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart';

class HistoryItem {
  final String text;
  final DateTime timestamp;

  HistoryItem({
    required this.text, 
    required this.timestamp
  });

  // Convert to Map (for JSON)
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create from Map (from JSON)
  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      text: map['text'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Helpers for SharedPreferences serialization
  String toJson() => json.encode(toMap());
  factory HistoryItem.fromJson(String source) => HistoryItem.fromMap(json.decode(source));
}

// 1. NOTIFIER: Manages the List<HistoryItem>
class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  final PreferencesService _prefsService;

  HistoryNotifier(this._prefsService) : super([]) {
    _loadHistory();
  }

  // Load from disk on startup
  void _loadHistory() {
    final jsonList = _prefsService.getHistory();
    // Convert List<String> -> List<HistoryItem>
    state = jsonList.map((jsonStr) => HistoryItem.fromJson(jsonStr)).toList();
  }

  // Add item (or move to top if exists)
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final cleanQuery = query.trim();
    final currentList = [...state];

    // Remove duplicates (so the new one bubbles to top)
    currentList.removeWhere((item) => item.text == cleanQuery);

    // Create new item
    final newItem = HistoryItem(text: cleanQuery, timestamp: DateTime.now());
    
    // Insert at top
    currentList.insert(0, newItem);

    // Limit size (optional: keep last 50 items)
    if (currentList.length > 50) {
      currentList.removeLast();
    }

    // Update State
    state = currentList;

    // Save to Disk
    _saveToPrefs();
  }

  Future<void> removeFromHistory(HistoryItem item) async {
    final currentList = [...state];
    currentList.remove(item);
    state = currentList;
    _saveToPrefs();
  }

  Future<void> clearAllHistory() async {
    state = [];
    await _prefsService.clearHistory();
  }

  // Helper to serialize and save
  void _saveToPrefs() {
    final jsonList = state.map((item) => item.toJson()).toList();
    _prefsService.setHistory(jsonList);
  }
}

// 2. PROVIDER: Injects the service
final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  // We use the same service provider defined in caching.dart
  // Note: Ensure preferencesServiceProvider is exported or imported correctly here
  // If you didn't define the provider in caching.dart, you can pass it via main override logic 
  // similar to searchEngineProvider.
  
  // Assuming strict architecture where we override in main:
  throw UnimplementedError('historyProvider must be overridden in main.dart');
});