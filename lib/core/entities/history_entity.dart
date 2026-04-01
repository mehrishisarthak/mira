import 'dart:convert';

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
