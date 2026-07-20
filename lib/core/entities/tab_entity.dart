import 'dart:convert';
import 'package:flutter/foundation.dart' show immutable;
import 'package:uuid/uuid.dart';

/// Marks "[copyWith]'s webError parameter was not passed" so `null` can mean
/// "explicitly clear" instead of colliding with "keep the current value".
///
/// Previously the same [Sentinel] value did both jobs: the parameter's
/// default *and* the public `clearWebError` constant callers passed to
/// request a clear. `webError is Sentinel` then matched both, so
/// `copyWith(webError: clearWebError)` — what `setWebError(id, null)`
/// actually sent — always fell into the "keep old value" branch. The clear
/// silently never happened. Concretely: browser_side_effects fires
/// `setWebError(tabId, null)` on every `loadStart`, so once a tab hit any
/// error it stayed on [CustomErrorScreen] forever, regardless of how many
/// later navigations succeeded — the URL bar could show a working page while
/// the error overlay never left.
///
/// `identical()` against one private, const-canonicalized instance can't
/// collide with any real value a caller passes (not even another `Sentinel`),
/// so `webError` is free to just be `String?` again: `null` unambiguously
/// means clear.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

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
    Object? webError = _unset,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      webError: identical(webError, _unset) ? this.webError : webError as String?,
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
