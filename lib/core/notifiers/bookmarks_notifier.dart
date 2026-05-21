import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/isar_database_repository.dart';
import 'package:mira/core/services/isar_schemas.dart';
import 'package:mira/core/services/database_providers.dart';

class BookmarksNotifier extends StateNotifier<List<BookmarkSchema>> {
  final IsarBookmarkRepository _repository;

  BookmarksNotifier(this._repository) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _repository.init();
      _repository.watchAll().listen((items) {
        state = items;
      });
    } catch (e, stack) {
      debugPrint('[MIRA] BookmarksNotifier init failed: $e\n$stack');
    }
  }

  Future<void> toggleBookmark(String url, String title) async {
    if (isBookmarked(url)) {
      await removeBookmark(url);
    } else {
      await addBookmark(url, title);
    }
  }

  Future<void> addBookmark(String url, String title) async {
    final newBookmark = BookmarkSchema()
      ..url = url
      ..title = title.isEmpty ? url : title
      ..dateAdded = DateTime.now();
    
    await _repository.put(newBookmark);
  }

  Future<void> removeBookmark(String url) async {
    final item = state.cast<BookmarkSchema?>().firstWhere((b) => b?.url == url, orElse: () => null);
    if (item != null) {
      await _repository.delete(item.id);
    }
  }

  bool isBookmarked(String url) {
    return state.any((b) => b.url == url);
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<BookmarkSchema>>((ref) {
  final repository = ref.read(bookmarksRepositoryProvider);
  return BookmarksNotifier(repository);
});
