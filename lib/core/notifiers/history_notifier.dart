import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/services/isar_database_repository.dart';
import 'package:qyx/core/services/isar_schemas.dart';
import 'package:qyx/core/services/database_providers.dart';

class HistoryNotifier extends StateNotifier<List<HistoryItemSchema>> {
  final IsarHistoryRepository _repository;
  StreamSubscription<List<HistoryItemSchema>>? _subscription;

  HistoryNotifier(this._repository) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _repository.init();
      _subscription = _repository.watchAll().listen((items) {
        if (mounted) state = items;
      });
    } catch (e, stack) {
      debugPrint('[MIRA] HistoryNotifier init failed: $e\n$stack');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Ghost mode is checked at call site — not watched here to avoid provider recreation.
  Future<void> addToHistory(String url, {String? title}) async {
    if (url.trim().isEmpty || url == 'about:blank') return;
    final resolvedTitle = (title == null || title.isEmpty) ? url : title;
    await _repository.upsertByUrl(url.trim(), resolvedTitle);
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
  return HistoryNotifier(repository);
});
