import 'dart:convert';
import 'package:flutter/foundation.dart' show immutable;
import 'package:uuid/uuid.dart';

@immutable
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final bool isLoading;

  BrowserTab({
    String? id,
    this.url = '',
    this.title = 'New Tab',
    this.isLoading = false,
  }) : id = id ?? const Uuid().v4();

  BrowserTab copyWith({
    String? id,
    String? url,
    String? title,
    bool? isLoading,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowserTab &&
          other.id == id &&
          other.url == url &&
          other.title == title &&
          other.isLoading == isLoading);

  @override
  int get hashCode => Object.hash(id, url, title, isLoading);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
    };
  }

  factory BrowserTab.fromMap(Map<String, dynamic> map) {
    return BrowserTab(
      id: map['id'] as String? ?? const Uuid().v4(),
      url: map['url'] as String? ?? '',
      title: map['title'] as String? ?? 'New Tab',
    );
  }

  String toJson() => json.encode(toMap());
  factory BrowserTab.fromJson(String source) => BrowserTab.fromMap(json.decode(source));
}
