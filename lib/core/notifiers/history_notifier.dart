import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/isar_database_repository.dart';
import 'package:mira/core/services/isar_schemas.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';

class HistoryNotifier extends StateNotifier<List<HistoryItemSchema>> {
  final IsarHistoryRepository _repository;
  final bool _isGhost;

  HistoryNotifier(this._repository, this._isGhost) : super([]) {
    _init();
  }

  Future<void> _init() async {
    if (_isGhost) return;
    
    try {
      await _repository.init();
      _repository.watchAll().listen((items) {
        state = items;
      });
    } catch (e, stack) {
      debugPrint('[MIRA] HistoryNotifier init failed: $e\n$stack');
    }
  }

  Future<void> addToHistory(String url, {String? title}) async {
    if (_isGhost || url.trim().isEmpty || url == 'about:blank') return;
    
    final item = HistoryItemSchema()
      ..url = url.trim()
      ..title = (title == null || title.isEmpty) ? url : title
      ..timestamp = DateTime.now();

    await _repository.put(item);
  }

  Future<void> removeFromHistory(int id) async {
    await _repository.delete(id);
  }

  Future<void> clearHistory() async {
    await _repository.clear();
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItemSchema>>((ref) {
  final repository = ref.read(historyRepositoryProvider);
  final isGhost = ref.watch(isGhostModeProvider);
  return HistoryNotifier(repository, isGhost);
});
