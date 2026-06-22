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
| O-09 | 🟡 | `tab_notifier` persists to SharedPreferences on every url/title event. | `tab_notifier.dart` | Verify the existing debounce covers this; if not, persist only on `loadStop` + tab actions. |

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
| O-19 | 🟡 | `_isNewerVersion` maps non-numeric semver segments to 0 → pre-release tags (`v2.0.0-beta.1`) mis-compared, updates silently skipped. *(unverified)* | `update_service.dart` | Strip prefixes / parse semver properly. |
| O-20 | 🟡 | Isar lazy-init has a race window between null-check and `Isar.open`. *(unverified)* | `isar_database_repository.dart` | Guard with a `Completer`. |

### Code health / Cleanup
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-21 | 🟡 | **Sparse tests** for hibernation LRU, ghost tabs, `reorderTab`, `_isValidUrl`, download notifiers, Isar repos. No integration tests. *(Side-effect engine-event mapping now covered — `browser_history_recording_test.dart`, added with D-20.)* | `test/` | Pure deterministic units (LRU, reorder, url-routing) are cheapest/highest-value first. |
| O-26 | 🟡 | Abstract `BrowserEngine.create()` factory imports the concrete `InAppWebViewEngine` (DIP violation). | `browser_engine_blueprints.dart` | Inject via a `shell/` provider instead. |
| O-27 | 🟡 | `ghost_notifier.dart` is a kitchen sink (7 providers incl. engine lifecycle). | `ghost_notifier.dart` | Split into ghost-state / active-tab / engine-factory files. |
| O-30 | ⚪ | `mocktail` dev-dep declared but unused; `flutter_lints` only, no strict rules. | `pubspec.yaml`, `analysis_options.yaml` | Consider stricter lints (`unawaited_futures`, etc.). |
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
