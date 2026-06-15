# Mira Browser — Issues Audit
_Generated: 2026-06-16_

---

## PRIORITY 1 — Critical Bugs

### [BUG-01] "Save Page" saves page title, not HTML
**File:** `lib/pages/mira_drawer.dart:259`

```dart
final html = await engine.currentTitle(); // Simple proxy for content extraction
```

`currentTitle()` returns the DOM `<title>` string, not page HTML. The saved `.html` file will contain just a few words (e.g. `"Google"`) instead of actual page markup. Needs a dedicated `getPageHtml()` method on `BrowserEngine` that calls `evaluateJavascript(source: "document.documentElement.outerHTML")`.

---

### [BUG-02] Ad-Block toggle does not affect existing WebViews
**Files:** `lib/shell/browser/in_app_webview_engine.dart:240-256`, `lib/pages/main_screen/main_screen_security.dart:54-67`

Content blockers are passed as `initialSettings` at WebView creation time:
```dart
contentBlockers: AdBlockService.adBlockRegexes.map(...).toList(),
```
`InAppWebViewEngine.updateSettings()` only sets `forceDark`, `userAgent`, and `preferredContentMode` — never content blockers. So toggling "The Shield" reloads the page (`forceReload: true`) but content blockers remain active in the native WebView process. The toggle gives false user feedback. To truly disable/enable ad-blocking you must rebuild the WebView widget (new engine instance).

---

### [BUG-03] `registerBrowserViewSideEffects` accumulates `addPostFrameCallback` on every rebuild
**File:** `lib/pages/browser/browser_side_effects.dart:77`

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!isMounted()) return;
  _syncEngineToChrome(ref, state.tabs, state.activeIndex);
});
```

This is called from `BrowserView.build()`. Every widget rebuild adds a new post-frame callback. On busy frames (tab switching, scroll, resize) multiple callbacks accumulate, each calling `_syncEngineToChrome` → `hibernationProvider.notifier.wakeTab()` → state update → new rebuild → repeat. The `ref.listen()` calls inside the same function are fine (Riverpod deduplicates per build cycle), but `addPostFrameCallback` is not deduplicated.

**Fix:** Move this initial sync into `initState` so it runs exactly once.

---

## PRIORITY 2 — Proxy Removal (User Requested)

The proxy system is iOS-only and no longer needed. It spans **7 files to delete** and **6 files to modify**.

### Files to delete entirely:
| File | Reason |
|------|--------|
| `lib/core/notifiers/proxy_notifier.dart` | `ProxyGatewayNotifier` / `proxyGatewayStatusProvider` |
| `lib/core/services/proxy_service.dart` | Abstract `ProxyService` interface |
| `lib/shell/proxy/proxy_provider.dart` | `proxyServiceProvider` factory |
| `lib/shell/proxy/proxy_service_ios.dart` | `IOSProxyService` — 369-line iOS local HTTP gateway |
| `lib/shell/proxy/proxy_service_stub.dart` | `StubProxyService` |
| `lib/shell/proxy/mira_ios_gateway_url.dart` | Gateway URL constants/helpers |
| `lib/pages/browser/effective_request_url.dart` | `effectiveBrowserUrl()` — proxy-only helper, never called (logic is inline in mainscreen) |

### Files to modify:

**`lib/core/entities/security_entity.dart`**
- Remove fields: `isProxyEnabled`, `proxyUrl`, `proxyAllowInsecureCertificates`
- Remove same from `copyWith()`, `==`, `hashCode`

**`lib/core/notifiers/security_notifier.dart`**
- Remove: `toggleProxy()`, `updateProxyUrl()`, `toggleProxyAllowInsecureCertificates()`
- Remove proxy field loading in `_loadSettings()`

**`lib/core/services/preferences_service.dart`**
- Remove keys: `_keyProxyEnabled`, `_keyProxyUrl`, `_keyProxyAllowInsecureTls`
- Remove methods: `getProxyEnabled/setProxyEnabled`, `getProxyUrl/setProxyUrl`, `getProxyAllowInsecureCertificates/setProxyAllowInsecureCertificates`

**`lib/core/services/browser_engine_blueprints.dart`**
- Remove: `ProxyConfig` abstract class
- Remove: `registerProxyConfig(ProxyConfig config)` from `BrowserEngine` abstract interface

**`lib/shell/browser/in_app_webview_engine.dart`**
- Remove: `_proxyConfig` field
- Remove: `registerProxyConfig()` implementation

**`lib/pages/mainscreen.dart`**
- Remove imports: `proxy_notifier.dart`, `proxy_service.dart`, `proxy_provider.dart`
- Remove proxy URL-wrapping block in `_performSearch()` (lines 182–190)
- Remove: `ref.watch(proxyGatewayStatusProvider)` in `build()`

---

## PRIORITY 3 — Dead Code

### [DEAD-01] `browserServiceProvider` + `BrowserService` — entirely unused
**Files:** `lib/core/services/browser_service.dart`, `lib/shell/browser/browser_service_stub.dart`, `lib/shell/browser/browser_provider.dart`

`browserServiceProvider` is marked `DEPRECATED` in a comment and returns a `StubBrowserService`. The `BrowserService` interface has `applyProxy()` (proxy-related dead end) and `onTabClosed()` (never called). Nothing reads this provider. All three files can be deleted.

---

### [DEAD-02] `SecurityState.isIncognito` — loaded and saved but never used
**Files:** `lib/core/entities/security_entity.dart`, `lib/core/notifiers/security_notifier.dart`, `lib/core/services/preferences_service.dart`

`isIncognito` is persisted to `SharedPreferences` and restored into `SecurityState`, but no code reads `securityState.isIncognito` to do anything. Ghost/private mode is controlled entirely by `isGhostModeProvider` (a runtime `StateProvider<bool>`). The only indirect use is `TabsNotifier.nuke()` reading `_prefsService.getIncognito()` directly as a bypass condition — reading the pref, not the state field. The field, its pref key, and all related methods can be removed.

---

### [DEAD-03] `effectiveBrowserUrl()` — defined, never called
**File:** `lib/pages/browser/effective_request_url.dart`

The function is defined but never imported anywhere. Proxy URL wrapping is duplicated inline in `mainscreen.dart:_performSearch()`. Covered by proxy removal above.

---

## PRIORITY 4 — Functional Gaps

### [GAP-01] Location Lock and Sensor Lock are UI-only — never applied to WebView
**Files:** `lib/core/notifiers/security_notifier.dart`, `lib/core/entities/security_entity.dart`

`isLocationBlocked` and `isCameraBlocked` are toggled in the drawer and persisted, but neither value is passed to `InAppWebViewSettings`. The WebView ignores these flags entirely — location and camera access depend solely on OS-level permission grants.

**Fix:** Add `isLocationBlocked` and `isCameraBlocked` to `BrowserEngineConfig` and apply in `updateSettings()`:
```dart
InAppWebViewSettings(
  geolocationEnabled: !config.isLocationBlocked,
  mediaPlaybackRequiresUserGesture: config.isCameraBlocked,
  // ...
)
```

---

### [GAP-02] History entries get the search query as title, not the actual page title
**File:** `lib/pages/mainscreen.dart:196`

```dart
ref.read(historyProvider.notifier).addToHistory(finalUrl, title: trimmedValue);
```

At the moment of submission, `trimmedValue` is what the user typed — e.g. `"flutter docs"` — not the rendered page title. The actual title arrives later via `BrowserPageEventType.titleChanged`, which only updates the tab entity, not the history entry. History always shows the typed query.

**Fix:** Add the history entry on `loadStop` (when title is known) rather than on URL submission, or update the history entry title when `titleChanged` fires.

---

### [GAP-03] `historyProvider` is recreated on every ghost-mode toggle
**File:** `lib/core/notifiers/history_notifier.dart:51`

```dart
final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItemSchema>>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  return HistoryNotifier(repository, isGhost);
});
```

Watching `isGhostModeProvider` tears down and recreates `HistoryNotifier` (and re-opens the Isar stream) every time the user enters or exits ghost mode. The `_isGhost` flag only guards writes. A lighter fix: keep one notifier and read `isGhostModeProvider` inside `addToHistory()` at call time.

---

### [GAP-04] `_updateTabUrl` / `_updateTabTitle` use `dynamic ref` — type unsafe
**File:** `lib/pages/browser/browser_side_effects.dart:149, 158`

```dart
void _updateTabUrl(dynamic ref, String url) { ... }
void _updateTabTitle(dynamic ref, String title) { ... }
```

Both helpers accept `dynamic` instead of a typed `Ref` or `WidgetRef`. This loses all static analysis on the ref parameter. Should be typed as `WidgetRef` (or the specific `AutoDisposeRef` variant).

---

## Summary Table

| ID | Severity | Category | File(s) |
|----|----------|----------|---------|
| BUG-01 | Critical | Bug | `mira_drawer.dart:259` |
| BUG-02 | High | Bug | `in_app_webview_engine.dart`, `main_screen_security.dart` |
| BUG-03 | Medium | Bug | `browser_side_effects.dart:77` |
| PROXY | High | Removal | 7 files deleted, 6 modified |
| DEAD-01 | Low | Dead Code | `browser_service.dart`, `browser_service_stub.dart`, `browser_provider.dart` |
| DEAD-02 | Low | Dead Code | `security_entity.dart`, `security_notifier.dart`, `preferences_service.dart` |
| DEAD-03 | Low | Dead Code | `effective_request_url.dart` |
| GAP-01 | High | Functional Gap | `security_notifier.dart`, `in_app_webview_engine.dart` |
| GAP-02 | Medium | Functional Gap | `mainscreen.dart:196`, `browser_side_effects.dart` |
| GAP-03 | Low | Functional Gap | `history_notifier.dart:51` |
| GAP-04 | Low | Code Quality | `browser_side_effects.dart:149,158` |
