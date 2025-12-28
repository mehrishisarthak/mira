import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart';
import 'package:mira/model/search_engine.dart';

class Bookmark {
  final String url;
  final String title;
  final DateTime dateAdded;

  Bookmark({
    required this.url,
    required this.title,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      url: map['url'] ?? '',
      title: map['title'] ?? 'No Title',
      dateAdded: DateTime.tryParse(map['dateAdded'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Bookmark.fromJson(String source) => Bookmark.fromMap(json.decode(source));
}

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