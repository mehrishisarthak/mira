import 'dart:convert';

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
  // Factory constructor to create a Bookmark instance from a Map.
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
