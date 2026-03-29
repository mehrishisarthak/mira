import 'dart:convert';

/// Pure data model for a single browsing history entry.
/// The provider and notifier that manage this model live in search_engine.dart,
/// co-located with the other preference-backed providers.
class HistoryItem {
  final String text;
  final DateTime timestamp;

  HistoryItem({
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      text: map['text'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  String toJson() => json.encode(toMap());
  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source));
}
