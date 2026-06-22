# MIRA — Issue Tracker

> **Living document.** Single source of truth for known issues, fixes, and
> dismissed findings. Supersedes and replaces the prior scattered audit files
> (`audit_report.md`, `definitive_audit_report.md`, `MIRA_DEFINITIVE_AUDIT.md`,
> `ISSUES_AUDIT.md`, `FULL_CODEBASE_VALIDATOR_REPORT.md`), all now deleted.
>
> **Last updated:** 2026-06-22
> **Legend:** 🔴 high · 🟠 medium · 🟡 low · ⚪ info/cosmetic · ✅ done · ❌ rejected

---

## OPEN

### Security / Privacy
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-01 | 🔴 | **Verify ghost/incognito cookie isolation on Android.** Clearing goes through the *global* `CookieManager`/`WebStorageManager`; Android incognito doesn't guarantee a separate cookie jar. | `in_app_webview_engine.dart:243-250` | Test on-device that a ghost cookie isn't visible to a normal tab, and a ghost clear can't nuke the main profile. Highest-value privacy item. |
| O-02 | 🟠 | **No navigation scheme allow-list** (defense-in-depth). `shouldOverrideUrlLoading` returns `ALLOW` unconditionally; relies on WebView defaults to refuse `file://`/`intent://`/`javascript:`/`data:`. | `in_app_webview_engine.dart:306` | Add an allow-list (`http/https/about/blob`), hand off `mailto:`/`tel:` to OS, drop the rest. Hardening, not a confirmed exploit. |
| O-03 | 🟡 | **Excessive Android storage perms** + `requestLegacyExternalStorage="true"` (disables scoped storage). | `AndroidManifest.xml:12,13,22` | Downloads now use app-scoped `getDownloadsDirectory()`; likely removable. Contradicts privacy brand. |
| O-04 | 🟡 | `saved_tabs` (normal-tab URLs/titles) stored as **plaintext** SharedPreferences. | `preferences_service.dart` | Ghost mode is correctly ephemeral; consider `flutter_secure_storage` for normal tabs if "privacy" is a hard claim. |

### Performance
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-06 | 🟡 | `BrowserView.build` watches the whole tab list; rebuilds the full `Stack` on every title/url tick. | `browser_view.dart:51` | `.select` to `(tab ids, activeIndex)` so heavy rebuild only fires on add/remove/switch. |
| O-07 | 🟡 | `Mainscreen.build` still watches broad slices (`tabsProvider`, `ghostTabsProvider` for count, full `bookmarksProvider`). | `mainscreen.dart:330-342` | Derive `tabCountProvider` / `isCurrentUrlBookmarkedProvider` and `.select`. (Progress watch already fixed — see D-10.) |
| O-08 | 🟡 | Desktop find bar re-injects a 175-line JS library on every keystroke / Next. | `desktop_find_bar.dart:193` | Inject the library once on open (flag), then only the command. Desktop only. |

### Memory / Lifecycle
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-11 | 🟡 | Force-kill tab loss: 500 ms save debounce + only `resumed` lifecycle handled → pending tab state lost on OS kill. *(unverified)* | `tab_notifier.dart`, `mainscreen.dart:122` | Flush `saved_tabs` on `paused`/`detached`. |
| O-12 | 🟡 | Unawaited prefs setters can silently swallow write failures → in-memory vs disk divergence. *(unverified)* | `*_notifier.dart`, `preferences_service.dart` | Low; consider surfacing/logging write errors. |

### Bugs
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-17 | 🟡 | Desktop "resume"/"retry" deletes the partial and restarts from byte 0 (no HTTP `Range`). | `download_service_desktop.dart:127-130` | Rename to "restart" or implement range-resume. Desktop. |
| O-18 | 🟡 | Desktop download has no timeout — a slow-loris server holds the handle indefinitely. *(unverified)* | `download_service_desktop.dart` | Add `.timeout(...)`. Desktop. |
| O-36 | 🟠 | **Desktop: address bar can't be focused/clicked once a page is loaded.** Loaded+unfocused renders the domain as `Text`+`GestureDetector`; tapping `requestFocus()`s the field but native WebView2 retains OS keyboard focus, so it never becomes editable. *(found in runtime pass — Windows)* | `desktop_browser_chrome.dart:234` | Likely `flutter_inappwebview_windows` limitation (see O-39). Force OS focus back to the Flutter view on tap; needs on-Windows iteration. |
| O-37 | 🟠 | **Desktop: back/forward buttons do nothing.** MIRA calls the correct API (`engine.goBack()/goForward()` → `_controller?.goBack()/goForward()`); the no-op is in the Windows webview backend. *(runtime pass — Windows)* | `desktop_browser_chrome.dart:67-80` | See O-39. Optionally gate buttons on `canGoBack/canGoForward` for an honest disabled state. |
| O-38 | 🟠 | **Desktop: trackpad scroll & pinch-zoom don't reach the page.** Standard `InAppWebView`, no gesture suppression in MIRA; trackpad gestures aren't forwarded to the native WebView2. *(runtime pass — Windows)* | `in_app_webview_engine.dart:292` | See O-39. Investigate gesture forwarding / `gestureRecognizers`; may be upstream. |
| O-39 | 🔴 | **Root cause: `flutter_inappwebview_windows` is materially incomplete** vs Android/iOS — proven by the boot-time `MissingPluginException` for `getDefaultUserAgent`. O-36/37/38 are symptoms. **Desktop is a tech-preview gated by this plugin; Android/iOS is the mature path.** | — (dependency) | Decide: (a) treat desktop as preview & focus mobile, (b) contribute upstream, or (c) swap the desktop engine (`webview_windows`/CEF) behind the existing `BrowserEngine` abstraction. |

### Code health / Cleanup
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-21 | 🟡 | **Sparse tests** — still missing: ghost-tab ops, `_isValidUrl`, download notifiers, Isar repos, integration tests. *(Now covered: side-effect engine-event mapping `browser_history_recording_test.dart` (D-20); semver compare `update_service_version_test.dart` (D-23); hibernation LRU `hibernation_notifier_test.dart` + `reorderTab` `tab_reorder_test.dart`.)* | `test/` | `_isValidUrl` needs extraction from `_MainscreenState` to be unit-testable; Isar repos need the native test harness. |
| O-26 | 🟡 | Abstract `BrowserEngine.create()` factory imports the concrete `InAppWebViewEngine` (DIP violation). | `browser_engine_blueprints.dart` | Inject via a `shell/` provider instead. |
| O-27 | 🟡 | `ghost_notifier.dart` is a kitchen sink (7 providers incl. engine lifecycle). | `ghost_notifier.dart` | Split into ghost-state / active-tab / engine-factory files. |
| O-30 | ⚪ | Adopt `unawaited_futures` — needs an 18-site `unawaited()`-wrap pass (mostly intentional fire-and-forget) + a runtime check on the nav/lifecycle sites before enabling. *(Done: 4 zero-noise correctness lints added — `cancel_subscriptions`, `close_sinks`, `avoid_empty_else`, `unnecessary_statements`. The "`mocktail` unused" claim was **stale** — it's used in `app_startup_smoke_test.dart`.)* | `analysis_options.yaml` | — |
| O-31 | ⚪ | Isar 3 is in community maintenance — long-term dependency risk to track. | — | Strategic, not a defect. |
| O-34 | ⚪ | Deprecated `Radio` API (`groupValue`/`onChanged`) — needs migration to a `RadioGroup` ancestor (behavior-sensitive). | `browser_sheet.dart:62-63` | Real refactor, not a one-liner. |
| O-35 | ⚪ | Unused local `seedY` — can't just delete (its `rng.nextDouble()` advances the RNG; removing it changes the particle animation). | `onboarding_screen.dart:291` | Reorder so the consumed value is actually used, or accept the warning. |

### Refactor — large / "god" files
Files carrying too many responsibilities; split for testability and readability (refactors, not defects).

| ID | Sev | File | Lines | Responsibilities to split out |
|----|----|------|------:|-------------------------------|
| O-32 | 🟡 | `lib/pages/mainscreen.dart` | 560 | Lifecycle observer, desktop hotkeys, window-title sync, `_performSearch`/URL parsing, pop handling, and the `isDesktop ? … : …` layout branches. Extract `DesktopMainScaffold` / `MobileMainScaffold` + a `MainScreenController` for search/hotkey logic. (Partially done — heavy helpers already in `main_screen/`.) |
| O-33 | 🟡 | `lib/pages/mira_drawer.dart` | 557 | Theme picker, search-engine picker, security toggles, ad-block toggle, Nuke, update check, and bookmark/history/download sheet launchers all in one `MiraMenuPage`. Split into per-section widgets. |
| O-27 | 🟡 | `lib/core/notifiers/ghost_notifier.dart` | 146 | *(see O-27 above)* — kitchen sink of 7 providers incl. engine lifecycle; split into ghost-state / active-tab / engine-factory files. |

### Release — Google Play Store readiness
Compliance/release gates, **separate from the code defects above**. Closing every `O-*` issue is **necessary but not sufficient** to publish — these must also be done. (Found 2026-06-22 while auditing Play shippability.)

| ID | Sev | Gate | Location | Notes |
|----|----|------|----------|-------|
| R-01 | 🔴 | **Release build is signed with the *debug* keystore.** Play rejects anything signed with the debug key. | `android/app/build.gradle.kts:37` | Create a real upload keystore, add a `release` signingConfig, enroll in Play App Signing. **Hard blocker.** |
| R-02 | 🔴 | **`targetSdk = 34`.** Since 2025-08-31 Play requires new apps *and updates* to target **API 35** (Android 15); a 34 submission is rejected. | `android/app/build.gradle.kts:29` | Bump `targetSdk` to 35, re-test (esp. permissions/back-gesture behavior). **Hard blocker.** |
| R-03 | 🟠 | **Broad storage perms** (`WRITE/READ_EXTERNAL_STORAGE` + `requestLegacyExternalStorage="true"`) trigger a Play storage-permissions review; likely unnecessary since downloads use app-scoped `getDownloadsDirectory()`. | `AndroidManifest.xml:12,13,22` | Remove, or file the storage-permission declaration. *(Same root as O-03.)* |
| R-04 | 🟠 | **Sensitive perms undeclared to Play:** `ACCESS_FINE_LOCATION`/`CAMERA`/`RECORD_AUDIO` (exist to grant *web pages* access) need a Permissions Declaration / prominent disclosure; location triggers a review form. | `AndroidManifest.xml:6,8,9` | Complete Play declaration + in-app prominent disclosure, or drop perms not actually required. |
| R-05 | 🟠 | **No published Privacy Policy URL and no Data Safety form** — both mandatory to submit (more so with the sensitive perms above and a privacy-branded listing). | — (Play Console) | Publish a privacy policy; complete Data Safety accurately to match real data behavior. |
| R-06 | 🟡 | **`store_url` must point to the Play listing**, not a GitHub APK — otherwise the force-update flow pushes users to off-Play distribution. Mechanically the app only `launchUrl`s it (no APK sideload), so this is config, not code. | `update_service.dart`, `mira-updates/version.json`, `update_screen.dart:86-94` | Point `store_url` at the Play listing; reconsider hard force-update UX. |
| R-07 | 🟡 | **Content rating + store listing assets** (screenshots, feature graphic, descriptions) not done. | — (Play Console) | Complete content-rating questionnaire; prepare listing assets. |
| R-08 | ⚪ | Confirm AAB (not APK) release artifact + versionCode/versionName strategy; 64-bit is handled by Flutter. | `build.gradle.kts` | Standard `flutter build appbundle`; verify signing applies to the AAB. |

### Feature gaps / roadmap
Missing *capabilities* (not defects) that separate "a reliable browser" from a
daily-driver competitive with Chrome/DDG/Firefox. **None are bugs** — the `O-*`
fixes add zero features; these are the second leg of the path. Severity here =
**daily-use impact**, not defect severity. (Compiled 2026-06-22.)

| ID | Impact | Capability | Notes |
|----|----|-----------|-------|
| F-01 | 🔴 | **Address-bar autocomplete / suggestions** — as-you-type dropdown from history, bookmarks, and search-suggest. | The single biggest "feels unfinished" gap. Today the URL bar only routes to a full URL or a search. Privacy angle: prefer local history/bookmark matches; gate remote search-suggest behind a setting. Touches `mainscreen`/`mobile_main_app_bar`/`desktop_browser_chrome`. |
| F-02 | 🔴 | **Password manager / autofill** — save + fill credentials. | Login-heavy users bounce without it. Needs secure credential storage (ties to O-04 `flutter_secure_storage`) + webview form integration / platform autofill. |
| F-03 | 🟠 | **Mobile find-in-page.** | Desktop-only today (`desktop_find_bar.dart`). Reuse the desktop JS find logic on mobile (also see O-08 on the inject-once perf fix). |
| F-04 | 🟠 | **Cross-device sync** (bookmarks / history / open tabs). | High value, heavy: needs an account + backend (or a privacy-preserving E2E sync). Strategic, not a quick win. |
| F-05 | 🟡 | **Reader mode** (declutter / readability view). | Inject a readability script + a styled reader view. |
| F-06 | 🟡 | **Translate page.** | Needs a translation backend or on-device model; privacy trade-offs to weigh. |
| F-07 | 🟡 | **Per-site settings** — cookies / location / camera / JS per origin. | Today these are *global* toggles only; mainstream browsers scope them per site. |
| F-08 | 🟡 | **Share integration** — share a page out; receive shared URLs/text in (Android `PROCESS_TEXT` query already declared). | Wire share-sheet out + an intent handler for inbound shares. |
| F-09 | ⚪ | **Desktop extensions.** | Likely **infeasible** on `flutter_inappwebview` (no extension runtime). Strategic/uncertain — track, don't promise. |
| F-10 | ⚪ | **Tab groups / pinned tabs.** | Nice-to-have organizational depth; basic tabs + reorder already exist. |

---

## DONE (this session)

### Merged to `master`
| ID | Item |
|----|------|
| D-01 | Weekly OTA tracker-blocklist pipeline (GitHub Actions + sha256-verified client + bundled fallback) |
| D-02 | GitHub Actions bumped to Node 24 (checkout v5 / setup-python v6 / action-gh-release v3) |
| D-03 | Onboarding first-run flag routed through `PreferencesService` |
| D-04 | "Download started" snackbar with VIEW → Downloads on the main download path |
| D-05 | Android notification-permission result captured/logged (download no longer silently un-notified) |
| D-06 | Mobile live-WebView cap 10 → 4 (memory/lag creep) |
| D-07 | Content-blocker list memoized (no rebuild of ~2.5k rules per settings change) |
| D-08 | Skeleton shimmer paused when not loading (`TickerMode`) — killed a perpetual ~60fps repaint |
| D-09 | Open downloaded files via `open_filex` by path (replaces flaky `FlutterDownloader.open`; also fixes saved-pages) |
| D-10 | Extracted `BrowserProgressBar`; `Mainscreen` no longer full-rebuilds on every progress tick |
| D-11 | Firebase-free speed-dial plan doc |

### Fixed, PR open — `chore/cleanup-batch`
| ID | Item |
|----|------|
| D-12 | Download port name uses `DownloadManager.portName` constant, not a literal (was O-22) |
| D-13 | Isolate payload length/type guard before indexing `data[0..2]` (was O-23) |
| D-14 | Deleted dead `lib/core/entities/search_entity.dart` (`class Search`, unused) (was O-24) |
| D-15 | Deleted dead re-export shim `lib/pages/browser_view.dart` (was O-28) |
| D-16 | Renamed `skelleton_loader.dart` → `skeleton_loader.dart` (was O-29) |
| D-17 | `activeUrlProvider` uses `safeActiveTab?.url ?? ''` — no crash on empty tabs (was O-14) |
| D-18 | `isForMainFrame ?? false` — subframe errors no longer trigger the full-screen error page (was O-15) |
| D-19 | Migrated all 63 `withOpacity()` → `withValues(alpha:)` (6 files); removed unused imports, dead `_onTap`, `dart:typed_data`; `activeColor` → `activeThumbColor`. Analyzer **74 → 3 issues, 0 errors** (remaining 3 = O-34, O-35). |
| D-20 | History now recorded on `loadStop` (not only `titleChanged`) so title-less pages/error pages/SPAs land in history; engine stamps current url onto `titleChanged` events so the title refiner keys off the event's url, not active-tab-at-event-time (was O-13). |
| D-21 | `_engineEventsSubscriptionProvider` is now `autoDispose.family` — its `pageEvents` subscription is torn down when an engine is de-activated instead of leaking one per engine ever activated (was O-10). |
| D-22 | `main()` no longer blocks the first frame: adblock cache warms off the critical path (and its 285KB decode runs off-isolate via `compute()`); UA platform-channel fetch deferred to a post-`runApp` callback. Cache-ready invariant held by the always-present ~1.8s+ splash buffer before the first engine (was O-05). |
| D-23 | `UpdateService` version compare now tolerates a `v` prefix and pre-release/build suffixes (`2.0.0-beta.1`, `1.4.0+42`) instead of throwing on `int.parse` and silently skipping updates; + `update_service_version_test.dart` (5 tests) (was O-19). |
| D-24 | All three Isar repos guard lazy-init with a shared-future (`_initFuture ??= _open()`) so concurrent first-callers can't both reach `Isar.open` (duplicate-instance throw); guard resets to null on failure so a transient lock stays retryable (was O-20). |
| D-25 | Desktop: added custom min/maximize/close window controls to the toolbar — the native title bar is hidden (`TitleBarStyle.hidden`) so the window previously had no min/max/close affordance. (found in runtime pass) |
| D-26 | Desktop: fixed collapsed-sidebar `RenderFlex` overflow — the 52px rail's header packed a `Spacer` + a 48px-min `IconButton`; now a single 40px-constrained centered toggle. (found in runtime pass) |

### Verified already-fixed (found resolved during audit triage — no action)
- O-25: `mainscreen` no longer imports `history_notifier` (orphaned import already gone).
- `CustomErrorScreen` is rendered on `webError` (`browser_view.dart`).
- `HistoryNotifier` & `BookmarksNotifier` cancel their stream subscriptions in `dispose()`.
- `UpdateScreen` "Skip" passes `nextScreen` (no crash/exit).
- History tap guards against double-`https://`.
- Bookmarks respect ghost mode (route to `ghostTabsProvider`).
- `HibernatedTabPlaceholder` uses `ref.watch(themeProvider)` (live theme).
- Ad-block toggle updates live WebViews (`updateSettings` sets `contentBlockers`).
- Location/camera flags applied to the WebView (`geolocationEnabled`, `onPermissionRequest`).
- `_performSearch` already guards whitespace-only input via `value.trim().isEmpty` (was O-16).
- O-09: `tab_notifier` does **not** persist on every url/title event — `updateUrl`/`updateTitle` route through a 500 ms `_scheduleSave()` debounce; only discrete actions (`addTab`/`closeTab`/`switchTab`/`reorderTab`/`nuke`) write immediately. Resolved by existing design. (The same debounce is the *risk* tracked by O-11 — pending write lost on OS kill.)

---

## ❌ REJECTED / NOT-A-BUG (documented so they aren't re-raised)

| Claim (from old reports) | Why dismissed |
|---|---|
| OTA source URL is `nicepkg/aspect-ratio` | **Hallucination.** Real URLs are `github.com/mehrishisarthak/mira/releases/...` |
| OTA file written to world-readable `systemTemp` | **False.** Written to `getApplicationSupportDirectory()` (sandboxed) |
| `DownloadsNotifier` runs a 600 ms `Timer.periodic` forever (battery) | **False.** `grep Timer.periodic lib/` → none; mobile uses the isolate-port bridge |
| `DownloadsNotifier` creates a new `IsarDownloadRepository` per read | **False.** Repo is injected (optional/nullable) |
| Test suite is one `1+1==2` test | **False.** 3 real test files incl. the strong `adblock_ota_test.dart` |
| `SafeArea(bottom: false)` is a notch bug | **By design** — bottom bar handles its own inset (`MediaQuery.padding.bottom`) |
| `_lastAutoHealAt` resets on rebuild | **False.** `State` fields survive rebuilds |
| `_isValidUrl` routing spaced input to search is a bug | **Correct behavior** (Chrome/Firefox do the same) |
| Cleartext traffic enabled = HIGH vuln | **Necessary** for a browser to load HTTP sites; Dart-level OTA/update calls are already HTTPS + sha256-verified |
