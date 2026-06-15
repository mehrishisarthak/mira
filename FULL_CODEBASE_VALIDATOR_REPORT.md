# MIRA Browser — Full Codebase Validator Report
_Mode: Validator | Scope: Entire codebase | Date: 2026-06-16_

Three criteria per finding:
1. Does it serve its purpose without side effects?
2. Is it the best Dart/Flutter industry standard?
3. Does it violate CLAUDE.md conventions?

Severity scale: **CRITICAL** → **HIGH** → **MEDIUM** → **LOW**

---

## CRITICAL

### [C-01] `UpdateScreen` "SKIP FOR NOW" crashes on iOS / silently exits on Android
**File:** `lib/pages/splashscreen.dart:76`, `lib/pages/update_screen.dart:69`

`SplashScreen` pushes `UpdateScreen` via `pushReplacement` without passing `nextScreen`:
```dart
// splashscreen.dart — nextScreen never passed
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => UpdateScreen(result: updateResult)),
);
```
Inside `UpdateScreen`, the "SKIP FOR NOW" button falls into the `Navigator.pop(context)` branch since `nextScreen == null`. But `pushReplacement` removed the `SplashScreen` from the stack. The navigation stack is `[UpdateScreen]` — popping the only route exits the app on Android and throws on iOS. User taps "Skip" → app dies.

**Fix:** Pass `nextScreen: widget.nextScreen` when pushing `UpdateScreen` from `SplashScreen`.

---

## HIGH

### [H-01] History screen rebuilds broken URLs — double `https://` prefix
**File:** `lib/pages/history_screen.dart:112`

```dart
if (item.url.contains('.') && !item.url.contains(' ')) {
  finalUrl = "https://${item.url}";  // BUG
}
```
`item.url` is stored as a fully-qualified URL (e.g. `https://google.com`). The check `contains('.')` is true for any URL, so this produces `https://https://google.com`. Every history tap navigates to a broken URL.

**Fix:**
```dart
finalUrl = (item.url.startsWith('http://') || item.url.startsWith('https://'))
    ? item.url
    : 'https://${item.url}';
```

---

### [H-02] `CustomErrorScreen` is fully implemented but never rendered
**File:** `lib/pages/custom_error_screen.dart`, `lib/pages/browser/browser_view.dart`

`CustomErrorScreen` is a complete, polished widget with error classification for SSL, 404, 5xx, and network failures. It is never mounted anywhere. When a WebView encounters an error, `browserChromeProvider.webError` is set, but no widget reads it to show the error screen. Users see a blank page or the native WebView error page.

The dead code block that was supposed to render it was cleaned up this session without wiring a replacement.

**Fix:** In `BrowserView.build()`, detect `webError` and overlay `CustomErrorScreen` over the active tab when active.

---

### [H-03] `BookmarksNotifier` stream subscription never cancelled — memory leak
**File:** `lib/core/notifiers/bookmarks_notifier.dart:17`

```dart
Future<void> _init() async {
  await _repository.init();
  _repository.watchAll().listen((items) {  // StreamSubscription discarded
    state = items;
  });
}
```
Identical pattern to the `HistoryNotifier` issue fixed this session. The `StreamSubscription` returned by `.listen()` is discarded. When `BookmarksNotifier` is disposed, the Isar stream continues emitting, the closure holds `this`, and the notifier cannot be GC'd.

**Fix:** Store the subscription and cancel in `dispose()` — exact same fix applied to `HistoryNotifier`.

---

### [H-04] Bookmarks screen ignores ghost mode — always navigates normal tab
**File:** `lib/pages/book_marks_screen.dart:57`

```dart
onTap: () {
  ref.read(tabsProvider.notifier).updateUrl(bookmark.url);  // Always normal
  ref.read(activeBrowserEngineProvider)?.loadUrl(bookmark.url);
  Navigator.pop(context);
},
```
If the user is in ghost mode and taps a bookmark, `tabsProvider` (normal tabs) is updated instead of `ghostTabsProvider`. The active ghost tab stays on its current URL, and the background normal tab gets the bookmark URL silently.

**Fix:** Check `isGhostModeProvider` and route to the appropriate notifier, mirroring the pattern in `_performSearch`.

---

## MEDIUM

### [M-01] `desktop_find_bar.dart` reinjects 175 lines of JS on every keystroke and every "Next"
**File:** `lib/shell/desktop/desktop_find_bar.dart:193`

```dart
Future<void> _runDesktopFindCommand(String expression) async {
  await engine.injectScript(_desktopFindScript);  // 175-line library on EVERY call
  await engine.injectScript(expression);
}
```
The full find library (175 lines) is re-injected before EVERY search character and EVERY `next()`/`prev()` call. While the script is idempotent (reads `window.__miraFindState || {...}`), the injection cost is paid on every keystroke. On a slow page this adds visible lag to live search.

**Fix:** Inject the library once when the find bar opens (via a `_libraryInjected` flag), then only inject the command expression thereafter.

---

### [M-02] `tab_notifier.dart` writes `SharedPreferences` on every URL and title update
**File:** `lib/core/notifiers/tab_notifier.dart:200`

`_updateActiveTab` always calls `_saveToPrefs()`, which is called by `updateUrl` and `updateTitle`. These are driven by WebView events (`onLoadStart`, `onLoadStop`, `titleChanged`). A page with 3 redirects triggers 6+ `SharedPreferences.setStringList` writes. On Android, shared preferences I/O runs on the main isolate and can cause jank on complex navigations.

**Fix:** Debounce `_saveToPrefs()` with a short timer (~300ms), or only persist on `loadStop` and tab-management actions (add, close, switch, reorder), not on every URL/title event.

---

### [M-03] `mainscreen.dart` has orphaned `history_notifier` import
**File:** `lib/pages/mainscreen.dart:11`

```dart
import 'package:mira/core/notifiers/history_notifier.dart';
```
After moving `addToHistory` to `browser_side_effects.dart` this session, `historyProvider` is no longer referenced in `mainscreen.dart`. The import is unused and will trigger a lint warning.

**Fix:** Remove the import.

---

### [M-04] `HibernatedTabPlaceholder` uses `ref.read` in `build()` — theme changes ignored
**File:** `lib/pages/browser/hibernated_tab_placeholder.dart:15`

```dart
final theme = ref.read(themeProvider);  // Snapshot only
```
`ref.read` takes a one-time snapshot in `build()`. If the user changes theme while a tab is hibernated, the placeholder keeps the stale colors. Should be `ref.watch(themeProvider)`.

---

### [M-05] `_performSearch` does not guard whitespace-only input
**File:** `lib/pages/mainscreen.dart:164`

```dart
void _performSearch(String value) {
  if (value.isEmpty) return;
  ...
  String trimmedValue = value.trim();
```
Guards against empty string but not whitespace-only. If `value = "   "`, `value.isEmpty == false`, `trimmedValue == ""`, and `_isValidUrl("")` returns false, so a search query for `""` is formed and loaded. Produces a search for literally nothing.

**Fix:** `if (value.trim().isEmpty) return;`

---

### [M-06] `downloader.dart` conditional export includes desktop service in Android binary
**File:** `lib/shell/download/downloader.dart`

```dart
export 'download_service_stub.dart'
    if (dart.library.io) 'download_service_desktop.dart';
```
`dart.library.io` is available on ALL native platforms including Android and iOS. This exports `DesktopDownloadService` into the Android binary. The platform provider correctly selects `MobileDownloadService` at runtime, but the desktop service code (using `HttpClient`, direct file I/O) is compiled into the Android APK unnecessarily, increasing binary size.

**Fix:** The split cannot be done at compile time with conditional exports (only library availability is checkable). The cleanest fix for Android launch is to accept this and document it, or split into separate files with the platform check in the file names.

---

### [M-07] `_handlePop` calls `canGoBack()` twice in the error path
**File:** `lib/pages/mainscreen.dart:204`

```dart
if (errorMessage != null) {
  if (await engine?.canGoBack() ?? false) { ... return; }
  // Falls through when canGoBack() == false
}
if (engine != null && await engine.canGoBack()) { ... }
```
When `errorMessage != null` and `canGoBack()` returns false, we fall through to the second `canGoBack()` call — two async WebView IPC calls for the same query. Not a crash, but wasteful. The second block should be `else if` or the error check restructured.

---

## LOW

### [L-01] `searchProvider` / `SearchNotifier` — complete dead code
**File:** `lib/core/notifiers/search_notifier.dart:40`

```dart
class SearchNotifier extends StateNotifier<Search> { ... }
final searchProvider = StateNotifierProvider<SearchNotifier, Search>((ref) { ... });
```
`searchProvider` is defined, never read anywhere in the codebase. `SearchNotifier.updateUrl()` is never called. The `Search` entity (`search_entity.dart`) is the state class for this unused notifier. All three can be deleted.

---

### [L-02] `browser_sheet.dart` shows raw engine key instead of display name
**File:** `lib/pages/browser_sheet.dart:59`

```dart
title: Text(engineKey.toUpperCase())
```
Shows `"BRAVE"` instead of `"BRAVE SEARCH"`. `SearchEngines.getName(engineKey)` already exists for this purpose and returns proper names. Should be `Text(SearchEngines.getName(engineKey))`.

---

### [L-03] `provider_observer.dart` uses `print` in production — logs in release builds
**File:** `lib/core/observers/provider_observer.dart:12`

```dart
// ignore: avoid_print
print('[MIRA] Provider error in $name — $error');
```
`print()` is not stripped in release builds. Provider errors will appear in Android logcat for all users. Should be `debugPrint()` which is a no-op in release mode.

---

### [L-04] `splashscreen.dart` fires haptic feedback without platform guard
**File:** `lib/pages/splashscreen.dart:58`

```dart
HapticFeedback.lightImpact();
```
Called unconditionally without checking `Platform.isAndroid || Platform.isIOS`. On desktop, this calls the platform channel with no handler registered and silently fails. Should be wrapped in `if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))`.

---

### [L-05] `bookmarks_notifier.dart` — unnecessary unsafe cast
**File:** `lib/core/notifiers/bookmarks_notifier.dart:43`

```dart
final item = state.cast<BookmarkSchema?>().firstWhere((b) => b?.url == url, orElse: () => null);
```
`state` is `List<BookmarkSchema>` (non-nullable). Casting to `List<BookmarkSchema?>` and null-checking `b?.url` is misleading — none of these items can be null. Cleaner:
```dart
final item = state.where((b) => b.url == url).firstOrNull;
```

---

### [L-06] `mainscreen.dart` desktop window title sync not debounced
**File:** `lib/pages/mainscreen.dart:264`

```dart
ref.listen<BrowserTab>(currentActiveTabProvider, (prev, next) {
  _syncDesktopWindowTitle(next);  // Async platform channel call on every tab change
});
```
`_syncDesktopWindowTitle` calls `desktopSetWindowTitle` — a platform channel call — on every `currentActiveTabProvider` change. Title changes fire on every `titleChanged` WebView event (multiple times per page). On a dynamic SPA this could fire 10+ times per navigation, causing rapid-fire window title updates. Not a crash, but noisy platform channel traffic.

---

## Summary Table

| ID | Severity | File | Issue |
|----|----------|------|-------|
| C-01 | **CRITICAL** | `splashscreen.dart`, `update_screen.dart` | "Skip" button crashes iOS / exits Android — `nextScreen` never passed |
| H-01 | **HIGH** | `history_screen.dart:112` | Double `https://` prefix on history tap — every history URL is broken |
| H-02 | **HIGH** | `custom_error_screen.dart`, `browser_view.dart` | `CustomErrorScreen` implemented but never mounted — errors show blank page |
| H-03 | **HIGH** | `bookmarks_notifier.dart:17` | Isar stream subscription never cancelled — memory leak |
| H-04 | **HIGH** | `book_marks_screen.dart:57` | Bookmark tap always routes to normal tabs, ignores ghost mode |
| M-01 | **MEDIUM** | `desktop_find_bar.dart:193` | 175-line JS library re-injected on every keystroke — find bar laggy |
| M-02 | **MEDIUM** | `tab_notifier.dart:200` | `SharedPreferences` write on every URL/title update — potential jank |
| M-03 | **MEDIUM** | `mainscreen.dart:11` | Orphaned `history_notifier` import (unused after session fix) |
| M-04 | **MEDIUM** | `hibernated_tab_placeholder.dart:15` | `ref.read` in build — theme changes not reflected on hibernated tabs |
| M-05 | **MEDIUM** | `mainscreen.dart:164` | Whitespace-only search input not guarded — loads empty search query |
| M-06 | **MEDIUM** | `downloader.dart` | Conditional export includes desktop download service in Android binary |
| M-07 | **MEDIUM** | `mainscreen.dart:204` | `canGoBack()` called twice in error-back path — redundant WebView IPC |
| L-01 | **LOW** | `search_notifier.dart:40` | `searchProvider` + `SearchNotifier` are dead code — never read anywhere |
| L-02 | **LOW** | `browser_sheet.dart:59` | Shows raw engine key ("BRAVE") instead of display name ("Brave Search") |
| L-03 | **LOW** | `provider_observer.dart:12` | `print()` instead of `debugPrint()` — logs provider errors in release |
| L-04 | **LOW** | `splashscreen.dart:58` | Haptic feedback without `Platform.isAndroid` guard |
| L-05 | **LOW** | `bookmarks_notifier.dart:43` | Unnecessary unsafe `cast<BookmarkSchema?>()` on non-nullable list |
| L-06 | **LOW** | `mainscreen.dart:264` | Desktop window title sync fires on every title event — no debounce |

---

## Priority Fix Order for Android Launch

1. **C-01** — "Skip Update" crashes the app. Blocks release.
2. **H-01** — Every history tap navigates to a broken URL. Core UX broken.
3. **H-04** — Bookmarks break in ghost mode. High-visibility UX bug.
4. **H-02** — Web errors are invisible. Users see blank pages with no feedback.
5. **H-03** — `BookmarksNotifier` memory leak. Worsens over time.
6. **M-05** — Whitespace search input. Easy one-liner.
7. **M-03** — Orphaned import. Easy cleanup.
8. **M-04** — Hibernated tab theme stale. Visual glitch.
