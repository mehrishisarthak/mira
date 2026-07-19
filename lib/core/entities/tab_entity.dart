import 'dart:convert';
import 'package:flutter/foundation.dart' show immutable;
import 'package:uuid/uuid.dart';

class Sentinel { const Sentinel(); }
const clearWebError = Sentinel();

@immutable
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;
  final String? webError;

  BrowserTab({
    String? id,
    this.url = '',
    this.title = 'New Tab',
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.webError,
  }) : id = id ?? const Uuid().v4();

  BrowserTab copyWith({
    String? id,
    String? url,
    String? title,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
    Object? webError = const Sentinel(),
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      webError: webError is Sentinel ? this.webError : webError as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowserTab &&
          other.id == id &&
          other.url == url &&
          other.title == title &&
          other.isLoading == isLoading &&
          other.canGoBack == canGoBack &&
          other.canGoForward == canGoForward &&
          other.webError == webError);

  @override
  int get hashCode => Object.hash(id, url, title, isLoading, canGoBack, canGoForward, webError);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'canGoBack': canGoBack,
    };
  }

  factory BrowserTab.fromMap(Map<String, dynamic> map) {
    return BrowserTab(
      id: map['id'] as String? ?? const Uuid().v4(),
      url: map['url'] as String? ?? '',
      title: map['title'] as String? ?? 'New Tab',
      canGoBack: map['canGoBack'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());
  factory BrowserTab.fromJson(String source) => BrowserTab.fromMap(json.decode(source));
}
