import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/bookmark_entity.dart';
import 'package:mira/core/services/preferences_service.dart';

class BookmarksNotifier extends StateNotifier<List<Bookmark>> {
  final PreferencesService _prefs;

  BookmarksNotifier(this._prefs) : super([]) {
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final List<String> saved = _prefs.getBookmarks();
    state = saved.map((e) => Bookmark.fromJson(e)).toList();
  }

  void toggleBookmark(String url, String title) {
    if (isBookmarked(url)) {
      removeBookmark(url);
    } else {
      addBookmark(url, title);
    }
  }

  void addBookmark(String url, String title) {
    final newBookmark = Bookmark(
      url: url,
      title: title.isEmpty ? url : title,
      dateAdded: DateTime.now(),
    );
    // Add to top of list
    state = [newBookmark, ...state];
    _saveToPrefs();
  }

  void removeBookmark(String url) {
    state = state.where((b) => b.url != url).toList();
    _saveToPrefs();
  }

  bool isBookmarked(String url) {
    return state.any((b) => b.url == url);
  }

  void _saveToPrefs() {
    final List<String> encoded = state.map((b) => b.toJson()).toList();
    _prefs.setBookmarks(encoded);
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<Bookmark>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return BookmarksNotifier(prefs);
});
