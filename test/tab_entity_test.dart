import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/core/entities/tab_entity.dart';

/// Regression coverage for the copyWith(webError:) "unset vs explicit clear"
/// distinction. A prior version used the same Sentinel value as both the
/// default marker AND the public "please clear" constant, so
/// `copyWith(webError: clearWebError)` was indistinguishable from "not
/// passed" and silently kept the old error forever -- once any tab hit a
/// load error it was stuck on the error screen regardless of how many later
/// navigations succeeded.
void main() {
  test('copyWith with no webError argument leaves the existing error', () {
    final tab = BrowserTab(webError: 'ERR_CONNECTION_FAILED');
    final result = tab.copyWith(title: 'New Title');
    expect(result.webError, 'ERR_CONNECTION_FAILED');
  });

  test('copyWith(webError: null) actually clears a previously-set error', () {
    final tab = BrowserTab(webError: 'ERR_CONNECTION_FAILED');
    final result = tab.copyWith(webError: null);
    expect(result.webError, isNull);
  });

  test('copyWith(webError: "...") sets a new error over an old one', () {
    final tab = BrowserTab(webError: 'ERR_OLD');
    final result = tab.copyWith(webError: 'ERR_NEW');
    expect(result.webError, 'ERR_NEW');
  });

  test('a clear survives a second no-op copyWith, matching loadStart firing '
      'setWebError(id, null) on every navigation', () {
    var tab = BrowserTab(webError: 'ERR_CONNECTION_FAILED');
    tab = tab.copyWith(webError: null); // e.g. setWebError(id, null)
    tab = tab.copyWith(url: 'https://example.com'); // unrelated update
    expect(tab.webError, isNull, reason: 'error must not resurrect on later, unrelated copyWith calls');
  });
}
