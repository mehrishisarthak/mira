# MIRA Browser — Architecture Deep Dive

A complete reference of every service, provider, and data flow in the app, written from a code-read of the actual source.

---

## 1. Layered Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Pages / UI  (mainscreen, browser_view, tab_screen) │
├─────────────────────────────────────────────────────┤
│  Riverpod Providers  (chrome, engine, tabs, etc.)   │
├─────────────────────────────────────────────────────┤
│  Notifiers  (tab, ghost, hibernation, download, …)  │
├─────────────────────────────────────────────────────┤
│  Services / Engines  (InAppWebViewEngine, download) │
├─────────────────────────────────────────────────────┤
│  Entities  (BrowserTab, MiraDownloadTask, …)        │
└─────────────────────────────────────────────────────┘
```

The app deliberately decouples the **browser shell** (what renders the WebView) from **tab state** (which URLs are open) and from the **chrome layer** (the address bar, progress, error overlays). This lets each layer evolve independently.

---

## 2. The BrowserEngine Abstraction

### 2.1 Interface — `BrowserEngine` (`browser_engine_blueprints.dart`)

Every browser capability behind a single interface:

| Method group | Methods |
|---|---|
| Lifecycle | `init()`, `dispose()`, `hibernate()`, `wake()` |
| Navigation | `loadUrl(url)`, `reload()`, `goBack()`, `goForward()`, `stopLoading()` |
| Queries | `canGoBack()`, `canGoForward()`, `currentUrl()`, `currentTitle()`, `lastProgress` |
| Settings | `updateSettings(BrowserEngineConfig)` |
| Privacy | `clearStorage()`, `clearCookies()`, `setUserAgent(ua)` |
| Scripting | `injectScript(js)` |
| Snapshot | `takeSnapshot()`, `getPageHtml()` |
| Widget | `buildWidget({tabId, initialUrl})` |
| Events | `pageEvents` (Stream) |

The `pageEvents` stream is the single wire that connects native WebView callbacks back into Riverpod state.

### 2.2 Concrete Implementation — `InAppWebViewEngine`

State held privately:

```
_controller: InAppWebViewController?   ← null until onWebViewCreated fires
_pendingUrl: String?                   ← stores URL if loadUrl() called before controller exists
_pendingHeaders: Map<String,String>?
_lastProgress: int = 100
_isPrivate: bool                       ← incognito WebView flag
_isCameraBlocked, _isLocationBlocked  ← updated by updateSettings()
_eventController: StreamController    ← broadcast stream for pageEvents
```

**Controller handshake — `setController()`:**

```
engine.loadUrl(url)                           engine.buildWidget()
      │                                              │
      │  _controller == null?                        │  onWebViewCreated fires
      │     YES → _pendingUrl = url                  │       ↓
      │                                        setController(ctrl)
      │                                              │
      │                                        _pendingUrl != null?
      │                                             YES → loadUrl(_pendingUrl)
      │                                                    _pendingUrl = null
```

This pattern lets `loadUrl()` be called before the WebView widget is actually mounted. The first `buildWidget()` that fires `onWebViewCreated` drains the pending URL.

**Double-load guard in `buildWidget()`:**  
If `_pendingUrl == initialUrl`, the pending call is discarded before building — `initialUrlRequest` in the widget handles it instead, preventing two simultaneous navigations.

**`buildWidget()` produces an `InAppWebView` with:**
- `key: ObjectKey(tabId)` — Flutter widget identity; same key = same widget instance reused across rebuilds
- `initialUrlRequest` — only applied on first mount (when key is new)
- `useShouldOverrideUrlLoading: true` — enables the plugin's URL interception path
- `useOnDownloadStart: true` — enables download interception
- `shouldOverrideUrlLoading: → NavigationActionPolicy.ALLOW` — resolves the plugin's native interceptor for every `controller.loadUrl()` call; without this callback, intercepted navigations never complete and `onLoadStop` never fires

**Event fan-out from native callbacks:**

Every `InAppWebView` callback is forwarded through `handleXxx()` methods, which update `_lastProgress` and emit to the `_eventController` broadcast stream. Any number of Riverpod listeners can subscribe without the engine knowing about them.

---

## 3. Provider Architecture

### 3.1 `browserEngineProvider` — `Provider.family<BrowserEngine, String>`

```dart
Provider.family<BrowserEngine, String>((ref, tabId) {
  final isGhostTab = ref.watch(ghostTabsProvider.select(
    (s) => s.tabs.any((t) => t.id == tabId),
  ));
  final engine = InAppWebViewEngine(isPrivate: isGhostTab);
  ref.onDispose(() => engine.dispose());
  return engine;
});
```

Key properties:
- **One engine per tab ID.** Riverpod family caches by `tabId`; the same engine instance is returned on every read/watch for a given tab.
- **Only invalidated when ghost status changes.** The `select()` narrows the watch to one boolean. Tab URL changes, hibernation, or any other state change does NOT recreate the engine.
- **Engine lifecycle matches tab lifecycle.** When `browserEngineProvider(tabId)` is disposed (tab closed), `engine.dispose()` runs, closing the stream controller and nulling the controller.

### 3.2 `browserChromeProvider` — `StateNotifierProvider<BrowserChromeNotifier, BrowserChromeState>`

The "chrome layer" — what the address bar and overlays watch:

```
BrowserChromeState {
  engine: BrowserEngine?    ← currently active engine
  loadingProgress: int      ← 0-100
  webError: String?         ← set by onReceivedError, cleared on navigation
}
```

Equality uses `identical()` for `engine`: setting the same engine object is always a no-op, preventing redundant rebuilds when `_syncEngineToChrome` is called multiple times.

### 3.3 `activeBrowserEngineProvider` — `Provider<BrowserEngine?>`

```dart
Provider((ref) => ref.watch(browserChromeProvider).engine)
```

A convenience re-export. The main screen and side effects use this to call `engine?.loadUrl()` without caring which tab is active.

### 3.4 `_engineEventsSubscriptionProvider` — `Provider.family<void, BrowserEngine>`

This provider is the bridge between a `BrowserEngine`'s `pageEvents` stream and Riverpod state:

```dart
Provider.family<void, BrowserEngine>((ref, engine) {
  final subscription = engine.pageEvents.listen((event) {
    switch (event.type) {
      case loadStart:   → setLoadingProgress(0); _updateTabUrl(url)
      case loadStop:    → setLoadingProgress(100); _updateTabUrl(url)
      case progress:    → setLoadingProgress(progress)
      case title:       → updateTabTitle(title); addToHistory(url, title)
      case error:       → setWebError(description)
      case download:    → downloadsProvider.notifier.startDownload(url, ...)
    }
  });
  ref.onDispose(() => subscription.cancel());
});
```

It is `ref.watch()`-ed inside `registerBrowserViewSideEffects()` each build cycle:

```dart
final activeEngine = ref.watch(activeBrowserEngineProvider);
if (activeEngine != null) {
  ref.watch(_engineEventsSubscriptionProvider(activeEngine));
}
```

Because `Provider.family` caches by the engine object (via `identical()`), the subscription is created once when an engine becomes active and cancelled when a different engine becomes active or the app disposes.

---

## 4. Tab System

### 4.1 `tabsProvider` / `ghostTabsProvider`

Both are `StateNotifierProvider<TabNotifier, TabsState>`. The ghost provider is a parallel instance for incognito tabs.

```
TabsState {
  tabs: List<BrowserTab>
  activeIndex: int
}
BrowserTab {
  id: String (UUID)
  url: String
  title: String
}
```

Key notifier methods: `addTab()`, `closeTab(id)`, `switchTab(index)`, `updateUrl(url)`, `updateTitle(title)`, `nuke()`.

`updateUrl()` writes to the **active tab** only. When navigation fires `onLoadStart`/`onLoadStop`, `_updateTabUrl()` in the side effects also calls `updateUrl()` so the tab's URL tracks the actual WebView URL (handles redirects, etc.).

### 4.2 `isGhostModeProvider` — `StateProvider<bool>`

Single boolean. When `true`, all active-tab reads/writes use `ghostTabsProvider` instead of `tabsProvider`. Ghost tabs have `incognito: true` WebViews.

### 4.3 `hibernationProvider` — `StateNotifierProvider<HibernationNotifier, Set<String>>`

Tracks which tab IDs have an active WebView. All others show `HibernatedTabPlaceholder`.

State is a `Set<String>` of **awake** tab IDs.

**`wakeTab(tabId)`:** Adds `tabId` to the set. Has an early-return no-op: if `tabId` is already the most-recently-used, no state change fires (prevents redundant `BrowserView` rebuilds from `_syncEngineToChrome` calls that happen on every tab state change).

**`onTabsClosed(remainingIds)`:** Removes IDs that are no longer in the tab list.

LRU eviction: when the awake set grows beyond a threshold, the least-recently-used tab is hibernated. Its WebView widget switches from `engine.buildWidget()` to `HibernatedTabPlaceholder` (a static screenshot or title card).

---

## 5. Browser Side Effects

`browser_side_effects.dart` is the coordination layer — it keeps tab state, engine state, and chrome state synchronized.

### 5.1 `registerBrowserViewSideEffects(ref)`

Called from `BrowserView.build()` on **every rebuild** (this is intentional — Riverpod's `ref.listen` inside a build is idempotent; re-registering the same listener is a no-op).

Registers five listeners:

```
tabsProvider        → _syncEngineToChrome (if !ghost mode)
                    → onTabsClosed (if tab count decreased)

ghostTabsProvider   → auto-exit ghost mode if all ghost tabs closed
                    → _syncEngineToChrome (if ghost mode)
                    → onTabsClosed

isGhostModeProvider → _syncEngineToChrome (switches which tabs/engine is active)

themeProvider       → applyMainScreenWebViewSettings()
securityProvider    → applyMainScreenWebViewSettings()
```

And one `ref.watch`:
```
activeBrowserEngineProvider → _engineEventsSubscriptionProvider(activeEngine)
```

### 5.2 `_syncEngineToChrome(ref, tabs, index)`

The central synchronization function. Called whenever the active tab changes.

```
1. tabs.isEmpty? → setEngine(null), return
2. wakeTab(tabId)          ← ensures the WebView is rendered
3. engine = browserEngineProvider(tabId)   ← stable engine for this tab
4. chromeNotifier.setEngine(engine)        ← NO-OP if same object (identical())
5. chromeNotifier.setLoadingProgress(engine.lastProgress)  ← sync progress from engine's internal state
```

Step 4's `identical()` check is crucial: switching between listeners that all call `_syncEngineToChrome` on every rebuild does not cascade into unnecessary UI rebuilds.

### 5.3 `syncInitialEngine(ref)`

Called once from `BrowserView.initState()` via `addPostFrameCallback`. Runs the same `_syncEngineToChrome` after the first frame so the initial tab's engine is wired to the chrome before any user interaction.

### 5.4 `applyMainScreenWebViewSettings(ref, {forceReload})`

Reads current theme + security state, builds a `BrowserEngineConfig`, and calls `engine.updateSettings(config)`. If `forceReload: true`, also calls `engine.reload()` (used when desktop mode is toggled, which requires a page reload to take effect).

---

## 6. BrowserView Rendering

`BrowserView` is a `ConsumerStatefulWidget` that renders ALL tabs as a `Stack`. Tabs not at the active index are hidden with `Visibility(visible: false, maintainState: true)` — their WebView state (scroll position, cookies, JS heap) is kept alive.

**Rendering decision per tab:**

```
tab.url.isEmpty
  → BrandingScreen (speed dial or ghost landing)  [key: brand_{tabId}]

!awakeTabIds.contains(tab.id)
  → HibernatedTabPlaceholder                      [key: hib_{tabId}]

otherwise
  → engine.buildWidget(tabId, initialUrl: tab.url) [key: vis_{tabId}]
```

The key change between states (`brand_` → `vis_`) causes Flutter to unmount the old widget and mount the new one. Within the `vis_` state, `ObjectKey(tabId)` is stable — Flutter reuses the `InAppWebView` across rebuilds, so `onWebViewCreated` fires only once per tab lifetime.

`initialUrl: tab.url` is passed on every rebuild, but since the `InAppWebView` is reused (same key), `initialUrlRequest` is only applied on first mount. Subsequent URL changes are driven by `engine.loadUrl()` calls.

---

## 7. Navigation Flows

### 7.1 Speed Dial Tile Tap

```
_DialTileState.onTapUp
  └─ tabsProvider.notifier.updateUrl(url)
        │
        └─ tabsProvider changes
              │
              ├─ BrowserView rebuilds → tab.url non-empty
              │     → engine.buildWidget(tabId, initialUrl: url)  ← first time; initialUrlRequest fires
              │
              └─ _syncEngineToChrome → setEngine(engine) → setLoadingProgress(100)
```

`engine.loadUrl()` is **never called**. The WebView loads via `initialUrlRequest` only. This path is unaffected by `shouldOverrideUrlLoading`.

### 7.2 Address Bar Search / URL Submit (`_performSearch`)

```
_performSearch(value)
  │
  ├─ clearWebError()
  ├─ finalUrl = _isValidUrl? "https://..." : formattedSearchUrlProvider(query)
  ├─ updateUrl(finalUrl)         ← tab state updated
  │     └─ _syncEngineToChrome  ← called synchronously from listener
  │
  └─ engine.loadUrl(finalUrl)   ← direct navigation call
        │
        ├─ _controller != null?
        │     YES → controller.loadUrl(finalUrl)
        │             └─ shouldOverrideUrlLoading fires (native intercept)
        │                   └─ Dart callback → NavigationActionPolicy.ALLOW
        │                         └─ navigation proceeds → onLoadStart → onLoadStop
        │
        └─ _controller == null? (new/empty tab)
              YES → _pendingUrl = finalUrl
                    │
                    └─ buildWidget() fires (BrowserView rebuild)
                          ├─ _pendingUrl == initialUrl? → clear _pendingUrl
                          └─ InAppWebView with initialUrlRequest=finalUrl
                                └─ onWebViewCreated → setController
                                      └─ _pendingUrl is nil → no extra loadUrl
```

`formattedSearchUrlProvider` is a `Provider.family<String, String>` that reads `searchEngineProvider` (defaults to Google) and returns `"${baseUrl}${Uri.encodeComponent(query)}"`.

### 7.3 Ghost Quick Launch Chips

```
_GhostLandingPage._navigate(query)
  ├─ ghostTabsProvider.notifier.updateUrl(query)
  └─ activeBrowserEngineProvider?.loadUrl(query)
```

Calls BOTH `updateUrl` and `loadUrl`. This is the same pattern as the address bar — the double-load guard in `buildWidget()` handles the new-tab case.

### 7.4 In-Page Link Navigation

User taps a link inside the WebView:
- Native WebView fires `shouldOverrideUrlLoading`
- Dart callback returns `NavigationActionPolicy.ALLOW`
- WebView loads the link
- `onLoadStart` → `_updateTabUrl(url)` → `tabsProvider.updateUrl(url)` → tab URL tracks actual URL
- `onLoadStop` → `setLoadingProgress(100)` → skeleton clears

---

## 8. Progress & Skeleton Overlay

### 8.1 Progress flow

```
native onPageStarted  → handleLoadStart()  → _lastProgress=0  → BrowserPageEvent(loadStart)
                                                                        │
                                                              _engineEventsSubscriptionProvider
                                                                        │
                                                              setLoadingProgress(0)
                                                              _updateTabUrl(url)

native onProgress     → handleProgressChanged(n) → _lastProgress=n → BrowserPageEvent(progress)
                                                                        │
                                                              setLoadingProgress(n)

native onPageFinished → handleLoadStop()   → _lastProgress=100 → BrowserPageEvent(loadStop)
                                                                        │
                                                              setLoadingProgress(100)
                                                              _updateTabUrl(url)
```

`_lastProgress` is stored on the engine so `_syncEngineToChrome` can re-seed `browserChromeProvider` with the correct value when switching active tabs.

### 8.2 `WebViewSkeletonOverlay`

Visibility predicate:
```
!isDesktop && loadingProgress < 100 && activeTabUrl.isNotEmpty
```

The skeleton is an animated shimmer that covers the WebView while loading. It disappears when `setLoadingProgress(100)` fires from `onLoadStop`. If `onLoadStop` never fires (e.g., due to the `shouldOverrideUrlLoading` bug that was fixed), the skeleton stays forever.

---

## 9. Download System

### 9.1 Call chain

```
InAppWebView.onDownloadStartRequest
  └─ InAppWebViewEngine.handleDownloadRequest(request)
        └─ CookieManager.getCookies()
        └─ _eventController.add(BrowserPageEvent(downloadRequested, req))
              │
              _engineEventsSubscriptionProvider.listen
                    │
                    downloadsProvider.notifier.startDownload(url, filename, headers)
                          │
                          DownloadsNotifier.startDownload
                                │
                                MobileDownloadService.startDownload(url, name, headers)
                                      │
                                      _checkPermission()
                                      _findMobilePath()
                                      FlutterDownloader.enqueue(...)
                                      onTasksReloaded(loadExistingTasks())
```

The download event is fired through the engine's page events stream, not as a direct callback, keeping the engine decoupled from any download-specific code.

### 9.2 `MobileDownloadService`

**Permission check — `_checkPermission()`:**

```
Platform.isAndroid?
  sdkInt >= 33?
    YES → Permission.notification.request()  ← Android 13+: shows OS notification dialog
          return true  (downloads always proceed)
    NO  → Permission.storage.request()
          isPermanentlyDenied? → openAppSettings(); return false
          isGranted? → return true; else return false
  else → return true
```

On Android 13+ (SDK ≥ 33), storage permission is not required. The only runtime permission needed is `POST_NOTIFICATIONS` (so `FlutterDownloader`'s `showNotification: true` actually shows the notification). The download proceeds regardless of whether the user grants notification permission.

**Background isolate bridge:**

`flutter_downloader` runs in a separate isolate. Progress updates are sent via a `SendPort` registered in `IsolateNameServer` under the name `'mira_download_port'`. `MobileDownloadService` listens on a `ReceivePort`, receives `[id, statusInt, progress]` tuples, and calls `onTaskUpdated()` to update the Riverpod state granularly (only the changed task, not the whole list).

### 9.3 `DownloadsNotifier` / `downloadsProvider`

`DownloadsNotifier` is a `StateNotifier<List<MiraDownloadTask>>`. It holds the full list of download tasks and exposes: `startDownload`, `pauseTask`, `cancelTask`, `resumeTask`, `retryTask`, `deleteTask`, `openTask`, `loadTasks`.

`downloadsProvider` wires `MobileDownloadService` on mobile (stub on desktop/web) with two callbacks:
- `onTasksReloaded` → replaces the full list in state
- `onTaskUpdated` → finds and updates a single task in the list by ID

`DownloadsPage` watches `downloadsProvider` and shows a `ListView` of tasks. It reloads from `flutter_downloader`'s SQLite DB on `initState` (tasks can be added from the background isolate between app launches).

---

## 10. Security / Permissions Panel

### 10.1 `securityProvider`

`StateNotifierProvider<SecurityNotifier, SecurityState>` with:
```
SecurityState {
  isLocationBlocked: bool
  isCameraBlocked: bool
  isDesktopMode: bool
}
```

### 10.2 `showSecurityDialogForUrl`

Guard: `if (activeUrl.isEmpty) return` — the security panel only makes sense on an active page.

The panel shows three toggles:
- **Location** — calls `toggleLocation()` + `applyMainScreenWebViewSettings()`
- **Camera & Mic** — calls `toggleCamera()` + `applyMainScreenWebViewSettings()`
- **Desktop Mode** — calls `toggleDesktop()` + `applyMainScreenWebViewSettings(forceReload: true)`

Desktop mode requires a page reload because the user-agent and preferred content mode only take effect for the next navigation.

### 10.3 `applyMainScreenWebViewSettings`

Reads `themeProvider` and `securityProvider`, builds a `BrowserEngineConfig`, and calls `engine.updateSettings(config)`. The engine applies the settings directly to the live WebView via `controller.setSettings()`.

These are also wired as side effects in `registerBrowserViewSideEffects` so changes to theme or security automatically re-apply settings to the current engine without the user needing to navigate.

---

## 11. Ghost Mode

Ghost tabs are managed by `ghostTabsProvider` — a parallel `TabsState` whose tabs get `InAppWebViewEngine(isPrivate: true)` WebViews. `incognito: true` in `InAppWebViewSettings` disables persistent cookies, cache, and form data at the native WebView level.

`isGhostModeProvider` (a `StateProvider<bool>`) determines which tab list is "active" in all UI and side-effect code. When ghost mode is active:
- `_syncEngineToChrome` reads from `ghostTabsProvider`
- `_updateTabUrl` / `_updateTabTitle` write to `ghostTabsProvider`
- History writes are skipped

**Entering ghost mode:** tap the ghost icon → `isGhostModeProvider = true`. If no ghost tabs exist, `ghostTabsProvider.addTab()` is called first.

**Exiting ghost mode (auto):** when the last ghost tab is closed, `ghostTabsProvider` listener detects `tabs.isEmpty` and sets `isGhostModeProvider = false`.

**`ghostTabsProvider.nuke()`:** closes all ghost tabs at once and clears their WebView state. Called from the tab sheet's "Close all" button when in ghost mode.

---

## 12. Onboarding

`OnboardingScreen` is a `PageView` with 3 pages, each animated by a custom `_BgPainter` (`CustomPaint`). Content fades and slides in/out via a single shared `AnimationController` that reverses, jumps the page, then forwards again. On completion, writes `is_first_run = false` to `SharedPreferences` and pushes `Mainscreen` with a fade transition.

---

## 13. Search Engine

`searchEngineProvider` is a `StateNotifierProvider<SearchEngineNotifier, String>` backed by `PreferencesService`. Initial state: `SearchEngines.google`. On first access, `_loadFromPrefs()` reads the saved engine key synchronously.

`formattedSearchUrlProvider` is a `Provider.family<String, String>` that takes a raw query, reads the current engine's base URL from `SearchEngines.getSearchUrl()`, and returns `"${baseUrl}${Uri.encodeComponent(query)}"`.

---

## 14. Data Flow Summary Diagram

```
User Action
    │
    ▼
mainscreen.dart / branding_screen.dart
    │
    ├── tabsProvider / ghostTabsProvider  ─────────────────────────────────────┐
    │       .updateUrl()                                                        │
    │       .addTab()                                                           │
    │       .closeTab()                                                         │
    │                                                                           │
    └── activeBrowserEngineProvider?.loadUrl()                                 │
                │                                                               │
                ▼                                                               │
        InAppWebViewEngine._controller?.loadUrl()                              │
                │                                                               │
                │ (native WebView)                                              │
                │                                                               │
         ┌──────┴──────────────────────────────────────────────┐               │
         │  onLoadStart / onProgressChanged / onLoadStop       │               │
         │  onTitleChanged / onReceivedError / onDownloadStart │               │
         └──────────────────────┬──────────────────────────────┘               │
                                │                                               │
                        pageEvents stream                                       │
                                │                                               │
                _engineEventsSubscriptionProvider.listen                        │
                                │                                               │
                ┌───────────────┼────────────────────────────┐                │
                │               │                            │                │
        setLoadingProgress  updateTabUrl             startDownload            │
                │               │                            │                │
                ▼               ▼                            ▼                │
        browserChromeProvider  tabsProvider ◄───────────────────────────────┘
                │               │           (listener in registerBrowserViewSideEffects)
                │               │
                │               └─ _syncEngineToChrome
                │                       └─ setEngine / setLoadingProgress
                │
                ▼
        BrowserView.build()
                │
                ├─ WebViewSkeletonOverlay  (progress < 100)
                ├─ CustomErrorScreen       (webError != null)
                └─ engine.buildWidget()   (active, awake tab)
```

---

## 15. Bug Fix Reference

### Bug 1 — No download permission dialog on Android 13+

**Root cause:** `_checkPermission()` returned `true` immediately for SDK ≥ 33. This is correct for storage (not required on Android 13+), but `POST_NOTIFICATIONS` must be requested at runtime — just declaring it in `AndroidManifest.xml` is not enough. Without the dialog, `FlutterDownloader`'s `showNotification: true` silently fails.

**Fix:** `await Permission.notification.request()` before returning `true` on SDK ≥ 33. Downloads proceed regardless of the user's choice; the dialog simply gives them the chance to enable notifications.

### Bug 2 — Address bar search shows loading shimmer forever

**Root cause:** `useShouldOverrideUrlLoading: true` was set in `InAppWebViewSettings` but no `shouldOverrideUrlLoading` callback was provided to the `InAppWebView` widget. On Android API 24+, the Android WebView's `shouldOverrideUrlLoading` fires for all `loadUrl()` calls (not just link taps). The plugin's native handler intercepts the navigation (returns `true` to Android to block it), sends the action to Dart via MethodChannel, receives no callback, and never resolves — so the navigation is started (`onLoadStart` fires, progress goes to 0, skeleton appears) but never completed (`onLoadStop` never fires). 

Speed dial was unaffected because it only uses `initialUrlRequest` (set at widget build time, loaded by the plugin internally on a path that bypasses the interceptor).

**Fix 1:** Add `shouldOverrideUrlLoading: (controller, navigationAction) async => NavigationActionPolicy.ALLOW` so all intercepted navigations are immediately resolved and allowed to proceed.

**Fix 2:** Clear `_pendingUrl` in `buildWidget()` when it equals `initialUrl`, preventing a second `controller.loadUrl()` call from racing with `initialUrlRequest` on new-tab navigation.

### Bug 3 — State Management Rebuild Amplifiers (Riverpod Footguns)

**Root cause:** The `StateNotifier` class (legacy Riverpod) uses `identical()` rather than `==` to determine if a new state should notify listeners. This caused three pervasive issues in the initial architecture:
1. **Redundant Allocations:** Notifiers like `BrowserChromeNotifier` or `TabsNotifier` called `state = ...` even when the underlying value (like loading progress or the URL) had not changed. This allocated a new object in memory (which fails `identical()`), triggering a rebuild cascade to all watchers.
2. **Missing `==` Overrides:** The `MiraTheme` entity was a plain class. Widgets using `.select((s) => s)` fell back to object identity for the selected field, causing rebuilds even if the theme structurally hadn't changed.
3. **Unscoped `ref.watch`:** The `Mainscreen` and `DesktopSidebar` watched full `TabsState` objects (e.g., `ref.watch(currentActiveTabProvider)`) without `.select`. A URL update from a background network request would trigger a full-screen or full-sidebar rebuild, causing micro-stutters during heavy loads.

**Fix:** 
1. **Early Returns:** Added same-value guards at the entry points of all setters (e.g., `if (value == state.loadingProgress) return;` or checking list structural equality before emitting).
2. **Equality Operators:** Added `operator ==` and `hashCode` to `MiraTheme` so that `.select` can properly memoize it.
3. **Targeted Watches:** Replaced `ref.watch(provider)` with `ref.watch(provider.select((s) => s.targetField))` in the root layout widgets to ensure they only rebuild when structurally necessary. Converts of top-level function builders like `buildMobileBottomBar` to `ConsumerWidget` classes isolated these scopes.
