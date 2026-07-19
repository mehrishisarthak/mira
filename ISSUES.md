# Qyx — Issue Tracker

> **Living document.** Single source of truth for known issues, fixes, and
> dismissed findings. Supersedes and replaces the prior scattered audit files
> (`audit_report.md`, `definitive_audit_report.md`, `MERIS_DEFINITIVE_AUDIT.md`,
> `ISSUES_AUDIT.md`, `FULL_CODEBASE_VALIDATOR_REPORT.md`), all now deleted.
>
> **Last updated:** 2026-07-19
> **Legend:** 🔴 high · 🟠 medium · 🟡 low · ⚪ info/cosmetic · ✅ done · ❌ rejected

---

## OPEN

### Security / Privacy
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|

### Performance
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| — | ℹ️ | **Perf caveat:** O-06/O-07 must be judged in `--profile`/release on Android, **not** debug (`flutter run`). Debug jank is an artifact; profile the specific interaction (perf overlay → UI vs raster thread) before optimizing the hot path. | — | Profile first. |

#### Mobile platform-view / rendering audit (2026-06-24)
UI-shell rendering pass focused on the Flutter↔native WebView bridge.

> **PROFILED 2026-06-24** (`--profile`, 60 Hz device, DevTools `flutterFrames` + `dumpsys meminfo` + logcat; traces in `profile test reports/`). Verdicts below are now **measured**, not estimated. Headline: the jank is **raster-thread / platform-view-bound**, not Dart-build-bound — the Riverpod rebuild work (O-06/O-07/D-29) was already clean. Root cause across O-42/O-48 (and O-49 — since corroborated by its *content-independent* tab-sheet lag and fixed via snapshot-swap, D-32) is the **Hybrid-Composition tax**: creating an `InAppWebView`, or animating Flutter content *over* a live one, stalls the UI/raster threads. **Device RAM still unknown — needed to finalize O-47 severity.**

| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-43 | 🟠❔ | **INCONCLUSIVE — likely NOT EXERCISED, must re-run.** Test B showed no jank, but the resize path only runs if a **heavy page was loaded** during the capture, and the evidence suggests it wasn't. **Do not reject yet; do not build the fix yet.** | `Test_B_Performance.json`, `AndroidManifest.xml:32` | **Evidence (Test B, 54 frames):** 0 build-janky, 1/54 raster-janky, **raster p50 4.1 ms** — vs **10–13 ms** in both webview-present traces. That low raster baseline implies the active `InAppWebView` was **not compositing** during the test (start page / no page), so the keyboard-resize-over-live-HC path was never triggered. **Re-run: load a heavy page, THEN focus the omnibox**, and confirm page state via logcat. Only then confirm-or-reject. |
| O-46 | 🟠 | **Edge-swipe back vs web horizontal scroll + predictive back.** `PopScope(canPop:false)` consumes the Android system back gesture for app/page nav; on Android 13+ the back gesture is an **edge swipe** that collides with horizontal scroll/carousels at the screen edge inside the page. With `targetSdk 35` (R-02) the predictive-back animation is also suppressed by `canPop:false`. Mobile gesture. | `mainscreen.dart:396-401`, `_handlePop` | Audit on-device with a horizontally-scrollable page. Consider predictive-back-aware `PopScope` once on SDK 35; evaluate gesture-exclusion at edges. |
| O-45 | ⚪ | **DEPRIORITIZED by profile.** Mainscreen shell full-rebuilds on active-tab url/title tick — residual after D-29. Profiling shows **build time is not the bottleneck** (p50 ~0.9 ms; jank is raster/platform-view-bound), so this is now a micro-cleanup, not a perf fix — and it isn't the safe one-liner first thought: desktop's address field reads `activeTab.url` in 5 places and both bars need `activeTab.title` for bookmark callbacks. | `mainscreen.dart:327`, `currentActiveTabProvider` | Only worth doing as hygiene: `select((t) => t.url)` + read `title` fresh in the bookmark callbacks. No measurable frame win expected. |

#### State-management & rebuild audit (2026-07-09)
Riverpod rebuild-scope audit focused on high-frequency state cascades from native WebView callbacks.

| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-65 | 🟡 | **`buildMobileBottomBar` / `buildDesktopToolbar` are functions, not widgets — no rebuild isolation.** Called from `Mainscreen.build()`, they don't create separate `Element` boundaries. Every Mainscreen rebuild reconstructs the entire bar widget tree. | `mobile_main_app_bar.dart:16`, `desktop_browser_chrome.dart:39` | Fix: Convert to `ConsumerWidget` classes. |
| O-74 | 🟡 | **`_DesktopAddressBar` stores `BuildContext` and `WidgetRef` as widget fields.** Anti-pattern — the context can become stale if the parent rebuilds. Should be a `ConsumerStatefulWidget`. | `desktop_browser_chrome.dart:237-238` | Fix: Refactor to `ConsumerStatefulWidget` with its own `ref`. |

#### Council / graphify raster & platform-view audit (2026-07-18)
Four-persona audit remainder, cross-validated against the `lib/` knowledge graph.
The **rebuild-scope half (O-79/O-80) is CLOSED** and **O-82 is CLOSED** (both in
DONE) — the remainder are raster / native-layer findings. O-81 is
**[NEEDS PROFILING]**: we believe it is a raster-thread bottleneck, but **do not
touch the code until a baseline `--profile` trace on a physical Android device
proves the delta** (per the perf caveat at the top of this section). O-83/O-84
are standard polish — no deep profiling required; pick them up on a
UI-optimization run.

| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-81 | 🟠 **[NEEDS PROFILING]** | **Snapshot-swap does not `Offstage` the live webview.** On sheet-open / omnibox-focus, `Image.memory` is layered *over* a still-mounted Hybrid-Composition surface, so D-32's "drop the surface out of the composite" is **not** achieved — only `pauseRendering()` stops frame *production*; the `PlatformViewLayer` is still composited every frame (Flutter does not occlusion-cull an opaque-covered platform view). | `browser_view.dart:127-131` (live-view Stack), D-32 | **Do not build the fix until a baseline `--profile` trace proves the raster delta.** Then: `Offstage(offstage: snapshotBytes != null, child: engine.buildWidget())` so the layer leaves the composite while staying alive. |
| O-83 | 🟡 | **`canGoBack()` IPC round-trip on every loadStart/loadStop/updateVisitedHistory.** Each async native hop then mutates `tabsProvider`; multiplies on SPA / redirect-heavy pages. No deep profiling needed. | `browser_side_effects.dart:29-39` | Coalesce to `loadStop` only, or gate the write behind an earlier same-value check. UI-optimization-run fodder. |
| O-84 | 🟡 | **`_GhostModeFlash` uses `Opacity` over the live surface.** `saveLayer` on every frame of the 550 ms flash, compositing a full-screen layer over the desktop WebView2 surface. One-shot, desktop-only. No profiling needed. | `mainscreen.dart:614` (`_GhostModeFlash`) | Animate a `ColoredBox` alpha via `Color.withValues(alpha:)`; drop the `Opacity` wrapper. |

#### Council / graphify dual-mode-stack raster pass (2026-07-19)
Post-`5f159bd` audit. Graph was current (no rebuild). **O-44 closed as stale.**
Rebuild-scope layer re-verified clean — no new state findings.

| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-87 | 🟠 | **`onTabsClosed` evicted the *other* mode's awake tabs.** `_mruSet` is global across both pools (dual-mode stack, `5f159bd`), but both listeners passed only their own pool's *surviving* ids while the method retained by `!contains`. Closing one normal tab tore down every live ghost webview → incognito session reloads and **loses state**. Latent before the dual-mode overhaul (only one pool mounted). | `hibernation_notifier.dart:27`, `browser_side_effects.dart:173,192` | **FIXED.** Method now takes `closedTabIds` + `removeAll`; both call sites already computed `closedIds`. Regression test added — old test only passed single-pool sets, which is why it never caught this. |
| O-85 | ❌ | **OVERSTATED — WITHDRAWN.** Claimed the snapshot-swap `Image.memory` needed a `cacheWidth` like every other snapshot site (**O-47**). It does not: those sites cap one *persistent thumbnail per tab*, whereas this is a **single transient full-bleed image**, cleared on sheet close, against Flutter's 100 MB default image cache. ~10 MB for ~1 s is not the O-47 OOM scenario — the finding pattern-matched the shape of the fix without checking the risk transferred. **Mis-sized twice:** first framed as a UI-thread decode stall (Flutter decodes off-thread — wrong mechanism), then "fixed" with a logical-width bound that decoded at ~360 px and upscaled 3× to full screen — **visibly blurry during the tab-sheet fade**, caught on device. Reverted; a comment at the call site now records why this site is deliberately unbounded. | `browser_view.dart:136` | **REVERTED.** Lesson: a guardrail that holds for N persistent images does not automatically hold for 1 transient one — check the risk, not the pattern. |
| O-86 | 🟡 | **`WebViewSnapshot` doc claimed `BrowserView` Offstages the HC surface.** It does not — the image layers over a still-composited surface. Likely why O-81 survived review. | `browser_chrome_providers.dart:105` | **FIXED (doc).** Rewritten to state the surface is masked, not dropped, with an explicit pointer to O-81 and the `pauseRendering()` distinction. |

**Closed by this pass:**

| ID | Resolution |
|----|-----------|
| O-44 | **STALE — CLOSED.** `browser_view.dart:129` now wraps the live engine in `RepaintBoundary`, added incidentally during the `5f159bd` dual-mode overhaul. Issue text no longer matches code. |

**O-81 addendum:** confirmed still open at `browser_view.dart:133-141`. The fix is
already the in-file pattern — the outer `Visibility(maintainState: true)` at
line 126 is the offstage-but-alive mechanism, applied one level inward. Remains
**[NEEDS PROFILING]**: do not build until a physical-device `--profile` trace
proves the raster delta.

**Verified non-findings (checked, no action):**
- Dual-mode stack does **not** double raster cost. `Visibility(visible:false,
  maintainState:true)` → `Offstage` → laid out but not painted, so the inactive
  mode's HC surface does leave the composite.
- State/rebuild layer clean post-O-79/O-80/O-82: `tabsSignature` structural
  watch, `.select((m) => m[tab.id])` hibernated scoping, and the
  `transitionActive` guard on the async `takeSnapshot()` all hold.

#### Test suite (2026-07-19)

| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-88 | ✅ | **FIXED — `app_startup_smoke_test` had 3 failing tests; the suite was NOT green.** D-28's "25/25 green" was stale. `SplashScreen.initState` constructed `InAppWebViewEngine` directly for the O-48 pre-warm, which throws `A platform implementation for flutter_inappwebview has not been set` under `flutter_test`, taking the whole splash build down — so every wordmark/branding assertion found nothing. Verified pre-existing at both `64e0819` and `79d9eab`: **not** caused by the Qyx rename or the logo work. Found only because a *full* `flutter test` was finally run instead of the five suites the branch had been gating on. | `splashscreen.dart`, `test/app_startup_smoke_test.dart` | **FIXED:** added an optional `preWarmEngineFactory` injection seam, mirroring the existing `httpClient` one; tests pass `() => null`, which the pre-existing null-guard in `build()` already handled. Production path unchanged. **Suite now 30/30 green.** |

### Memory / Lifecycle
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-12 | 🟡 | Unawaited prefs setters can silently swallow write failures → in-memory vs disk divergence. *(unverified)* | `*_notifier.dart`, `preferences_service.dart` | Low; consider surfacing/logging write errors. |

### Bugs
| ID | Sev | Issue | Location | Notes |
|----|----|-------|----------|-------|
| O-17 | 🟡 | Desktop "resume"/"retry" deletes the partial and restarts from byte 0 (no HTTP `Range`). | `download_service_desktop.dart:127-130` | Rename to "restart" or implement range-resume. Desktop. |
| O-36 | 🟠 | **Desktop: address bar can't be focused/clicked once a page is loaded.** Loaded+unfocused renders the domain as `Text`+`GestureDetector`; tapping `requestFocus()`s the field but native WebView2 retains OS keyboard focus, so it never becomes editable. *(found in runtime pass — Windows)* | `desktop_browser_chrome.dart:234` | Likely `flutter_inappwebview_windows` limitation (see O-39). Force OS focus back to the Flutter view on tap; needs on-Windows iteration. |
| O-37 | 🟠 | **Desktop: back/forward buttons do nothing.** Qyx calls the correct API (`engine.goBack()/goForward()` → `_controller?.goBack()/goForward()`); the no-op is in the Windows webview backend. *(runtime pass — Windows)* | `desktop_browser_chrome.dart:67-80` | See O-39. Optionally gate buttons on `canGoBack/canGoForward` for an honest disabled state. |
| O-38 | 🟠 | **Desktop: trackpad scroll & pinch-zoom don't reach the page.** Standard `InAppWebView`, no gesture suppression in Qyx; trackpad gestures aren't forwarded to the native WebView2. *(runtime pass — Windows)* | `in_app_webview_engine.dart:292` | See O-39. Investigate gesture forwarding / `gestureRecognizers`; may be upstream. |
| O-39 | 🔴 | **Root cause: `flutter_inappwebview_windows` is materially incomplete** vs Android/iOS — proven by the boot-time `MissingPluginException` for `getDefaultUserAgent`. O-36/37/38 are symptoms. **Desktop is a tech-preview gated by this plugin; Android/iOS is the mature path.** | — (dependency) | **DECIDED (2026-06-22): defer.** Build a **custom desktop engine API** — our own bindings to a real browser engine (e.g. CEF/Chromium), *not* an existing plugin — behind the existing `BrowserEngine` abstraction. **Sequencing: only AFTER the Android stable build is live on the Play Store.** Until then desktop stays a preview and O-36/37/38 are accepted preview limitations. |

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
| O-27 | 🟡 | `lib/core/notifiers/ghost_notifier.dart` | 146 | *(see O-27 above)* — kitchen sink of 7 providers incl. engine lifecycle; split into ghost-state / active-tab / engine-factory files. |

### Release — Google Play Store readiness
Compliance/release gates, **separate from the code defects above**. Closing every `O-*` issue is **necessary but not sufficient** to publish — these must also be done. (Found 2026-06-22 while auditing Play shippability.)

| ID | Sev | Gate | Location | Notes |
|----|----|------|----------|-------|
| R-01 | 🔴 | **Release build is signed with the *debug* keystore.** Play rejects anything signed with the debug key. | `android/app/build.gradle.kts:37` | Create a real upload keystore, add a `release` signingConfig, enroll in Play App Signing. **Hard blocker.** |
| R-02 | 🔴 | **`targetSdk = 34`.** Since 2025-08-31 Play requires new apps *and updates* to target **API 35** (Android 15); a 34 submission is rejected. | `android/app/build.gradle.kts:29` | Bump `targetSdk` to 35, re-test (esp. permissions/back-gesture behavior). **Hard blocker.** |
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
| F-02 | 🔴 | **Password manager / autofill** — save + fill credentials. | Login-heavy users bounce without it. Needs secure credential storage (`flutter_secure_storage` is now a dependency as of D-35) + webview form integration / platform autofill. |
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

### Merged to `master` — Security & Privacy
| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-01 | **O-01**: Verified on-device that `incognito: true` provides a memory-isolated cookie/storage jar by default. No cross-leakage exists between ghost tabs and normal tabs. |
| O-02 | **O-02**: Implemented an explicit scheme-based navigation allow-list in `InAppWebView` via `shouldOverrideUrlLoading`. Allowed `http/https/about/blob`. Handoff to OS for `mailto/tel/sms` via `url_launcher`. Blocked all other dangerous schemes (e.g., `file`, `javascript`, `intent`). |

### Merged to `master` — Phase 3 (Grid Redesign & Hybrid Caching)
| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-42 | **O-42**: Replaced heavy native WebView unmounts with a hybrid snapshot caching strategy (RAM for ghost, disk for normal tabs) and a seamless `_TabGridCard` UI to mask transition delays. |
| O-47 | **O-47**: Resolved OOM risks by implementing memory guardrails (`cacheWidth: 400`) on all loaded snapshots and capping active Hybrid Composition native views dynamically based on device RAM. |
| O-48 | **O-48**: Pre-warmed the `InAppWebViewEngine` synchronously during the `SplashScreen` animation boot sequence, absorbing the cold-start creation penalty off the UI thread. |
| O-55 | **O-55**: Transitioned the Tab Sheet to a `SliverGrid` mapping over raw snapshots (`Image.memory` and `Image.file`) rather than offstage native webviews, collapsing the widget tree bloat. |

### Merged to `master` — 2026-07-09 state-management & perf pass
| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-52 | **O-52**: Disabled `useShouldOverrideUrlLoading` natively. Dart was intercepting every single navigation request just to return `ALLOW`. Turning this off drops the IPC cost entirely, letting the OS handle routing. (Subsequently re-enabled with a scheme filter for O-02). |
| O-58 | **O-58**: Added strict `.select((s) => s.activeTab)` scoping to `currentActiveTabProvider` to prevent amplifier cascade. |
| O-59 | **O-59**: Added same-value guard (`if (url == state.activeTab.url) return;`) to prevent generating identical `TabsState` instances. |
| O-60 | **O-60**: Parallelized `takeSnapshot()` with the UI animation. The sheet now opens instantly without blocking the UI thread waiting for the engine capture. |
| O-62 | **O-62**: Added `if (value == state.loadingProgress) return;` early return to skip identical `BrowserChromeState` allocations. |
| O-63 | **O-63**: Added same-value guard to `GhostTabsNotifier` to stop redundant mutations on ghost navigations. |
| O-68 | **O-68**: Added custom `AnimationController` with `Curves.easeOutQuint` over 250ms for a snappier 120Hz feel. |
| O-69 | **O-69**: Added `@immutable`, `operator ==`, and `hashCode` to `MiraTheme`. Fixed a massive rebuild storm where Riverpod falsely dirtied the tree for identical theme states. |
| O-70 | **O-70**: Throttled `onProgressChanged` bridge events via a 5% delta rule (`abs() >= 5` or 0/100 bounds). Shielded the Dart bridge from 100+ micro-updates per load. |
| O-71 | **O-71**: Refactored `DesktopSidebar` to use a custom `_SidebarTabScope` for `.select` watchers, completely preventing global sidebar rebuilds on URL/title ticks. |
| O-73 | **O-73**: Added `_popInProgress` boolean lock to `_handlePop()` to prevent double-back-gesture race conditions. |
| O-57 | **O-57**: Scoped `currentActiveTabProvider` down to `.select((s) => s.activeTab)` (and `safeActiveTab` for ghost) so the UI doesn't rebuild when other non-active tab fields mutate. |
| O-72 | **O-72**: Prevented `currentActiveTabProvider` from watching `tabsProvider` while in ghost mode, stopping the evaluation cascade during normal-tab background updates. |
| O-67 | **O-67**: Scoped `activeTabIdProvider` and `currentTabListProvider` using `.select` directly within the providers so downstream listeners don't evaluate on progress/URL ticks. |
| O-66 | **O-66**: Scoped `activeBrowserEngineProvider` to `browserChromeProvider.select((s) => s.engine)` to avoid re-evaluations during page load progress ticks. |
| O-78 | **O-78**: Scoped `activeUrlProvider` to `.select((s) => s.safeActiveTab?.url ?? '')` to halt propagation. |
| O-61 | **O-61**: Injected `gestureRecognizers` into `InAppWebView` instantiation (`VerticalDragGestureRecognizer` and `HorizontalDragGestureRecognizer`) to let native scroll capture events properly and prevent conflicts with Flutter gesture navigation. |
| O-75 | **O-75**: Bound `ValueKey(tab.id)` to all `_TabRow` elements inside `tab_screen.dart` SliverLists, fixing a costly layout churn during tab reordering or closing. |
| O-76 | **O-76**: Converted the eager `ListView` in `desktop_sidebar.dart` to a true lazy `ListView.builder` utilizing a list of dynamic closures instead of complex index math. This drastically cuts layout overhead for power users with 20+ tabs. |
| O-77 | **O-77**: Tracked `_lastDomain` in the `_DesktopAddressBar` and guarded `setState` within `_onControllerChange`, preventing wasted DOM repaints when the URL updates behind an unfocused address bar. |

### Merged to `master` — 2026-07-18 rebuild-audit re-close (D-29 regression)
Surfaced by a graphify AST pass: `tabsProvider` is the single most-connected node
in the `lib/` knowledge graph (39 edges), so its watch-scoping is load-bearing for
the whole reactive tree. The `5f159bd` dual-mode-stack overhaul had silently
reverted **D-29** — both build roots watched `tabsProvider` unscoped again. Traced
the crossfire in-graph (only 2 of 39 referencing sites were actual unscoped
`watch`; Sidebar/ProgressBar/Skeleton were already `.select`-scoped), re-closed,
and verified (`flutter analyze` clean; `browser_navigation_smoke` + `tab_reorder`
+ `browser_history_recording` all green).

| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-79 | **Mainscreen watched `tabsProvider` unscoped (×2).** Swapped `ref.watch(tabsProvider).safeActiveTab` → `currentActiveTabProvider` and `.tabOrder.length` → `tabCountProvider` — value-identical, narrower rebuild trigger (background-tab mutations no longer rebuild the shell/omnibox). `mainscreen.dart`. |
| O-80 | **BrowserView watched `tabsProvider` + `ghostTabsProvider` unscoped.** Restored the D-29 structural-signature pattern, adapted to the dual-mode stack + per-tab `webError`: `.select` an `(activeIndex \| per-tab id:url-empty:webError)` signature on both providers, then `ref.read` the full state for the build. url/title/canGoBack ticks during load no longer rebuild the platform-view `Stack`. `browser_view.dart`. |

### Merged to `master` — 2026-07-19 O-82 close (snapshot service deleted)
| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-82 | **`preemptiveSnapshotProvider` inert + latent rebuild bomb → DELETED, not rewritten.** Review found the wanted event-driven capture *already exists*: `tabSnapshotCacheProvider` is populated on tab-loses-focus (`mainscreen.dart:370` switch listener) and Tab-Grid tap (`mobile_main_app_bar.dart:179`), both masked by animation, and it's the same cache the Tab Grid reads (`tab_screen.dart:287`). The only defect was that `HibernatedTabPlaceholder` read a **different, never-fed** provider. **Approach:** deleted `preemptive_snapshot_service.dart` entirely (the 15 s timer, the unhandled `try/catch`, the redundant store), and repointed `browser_view.dart`'s hibernated branch to `tabSnapshotCacheProvider.select((m) => m[tab.id])`. Fixes the functional gap (hibernated tabs now show the real captured thumbnail) **and** the rebuild bomb (scoped read) in one line, unifies grid + hibernated thumbnails to one source of truth, and adds **zero** new `takeScreenshot()` calls — so the [NEEDS PROFILING] concern is moot (no new GPU readback to profile). Verified: `flutter analyze` clean; `browser_navigation_smoke` + `tab_reorder` + `ghost_mode_isolation` + `nuke_data` green. |

### Merged to `master` — 2026-06-30 perf / lifecycle pass
Found in the platform-view audit (mobile-first). Approaches recorded for each.

| ID | Item (issue → approach taken) |
|----|-------------------------------|
| D-30 | **Opaque WebView surface (was O-50, new finding).** Audit found every `InAppWebView` created with `transparentBackground: true`, forcing the Hybrid-Composition surface to alpha-blend every frame though nothing renders behind the active webview (branding is a sibling shown only on empty url; the skeleton is an opaque overlay on top). **Approach:** removed the flag so the surface composites opaque (default). Emulator-verified no white/dark-page flash; raster win still to confirm on physical hardware. `in_app_webview_engine.dart`. |
| D-31 | **Scoped the desktop find-bar chrome watch + documented the notify footgun (was O-51, new finding).** `desktop_find_bar` watched `browserChromeProvider` unscoped, rebuilding on every progress tick. Root cause is general: `BrowserChromeNotifier` allocates a fresh state per setter and `StateNotifier` notifies by `identical()`, so the hand-written `==` never suppresses a notification — *any* unscoped watch is a per-tick rebuild. **Approach:** `.select((s) => s.engine)` at the call site + a comment on `BrowserChromeState.==` that it is consulted only by `.select`. `desktop_find_bar.dart`, `browser_chrome_providers.dart`. |
| D-32 | **Snapshot-swap the webview while the tab sheet is open (was O-49).** The lag was content-independent (static and video pages stutter equally) → not the page producing frames, but the HC compositing tax: a live platform-view surface composited under the animating sheet every frame. `TabsSheet` itself is cheap (verified), so not the sheet build. **Approach:** on tab-count tap, `takeSnapshot()` the active page into `webViewSnapshotProvider` (scoped `WebViewSnapshot{tabId,bytes}`); `BrowserView` Offstages that tab's live webview and paints the screenshot, dropping the surface out of the composite while keeping the native view alive (no reload — same offstage-but-alive pattern as inactive tabs). Tab-scoped so switching tabs from the sheet renders the new tab live, not a stale shot. `hibernate()` (native pause) on open / `wake()` on close so a video page stops producing frames behind the sheet. Null capture → live-view fallback (no regression). `mobile_main_app_bar.dart`, `browser_view.dart`, `browser_chrome_providers.dart`. **Pending:** physical-device confirmation (lag was user-reported, never profiled). |
| D-33 | **Flush pending tab save on app pause/detach (was O-11).** Tab url/title persist through a 500 ms debounce and the lifecycle observer only handled `resumed`, so a change inside the debounce window was lost on OS kill while backgrounded. **Approach:** added `TabsNotifier.flush()` (cancel pending debounce + write immediately, no-op if nothing pending) called from `didChangeAppLifecycleState` on `paused`/`detached`. Ghost tabs are intentionally ephemeral and not flushed. `tab_notifier.dart`, `mainscreen.dart`. |
| D-34 | **Timeouts on desktop downloads (was O-18).** The desktop `HttpClient` download had no timeout, so a server that connected then stalled held the socket + file handle open indefinitely. **Approach:** `connectionTimeout` (30 s) for the connect phase, `request.close().timeout(30 s)` for the header wait, `response.timeout(60 s)` per-chunk idle timeout for a connected-then-silent (slow-loris) server, and the `catch` now closes the sink + force-closes the client so a timeout actually releases the handles. Desktop preview path (gated by O-39). `download_service_desktop.dart`. |
| D-35 | **Encrypt saved tabs at rest (was O-04).** Normal-tab URLs/titles sat in plaintext SharedPreferences XML, contradicting the privacy brand (ghost tabs were already ephemeral). **Approach:** store the `saved_tabs` JSON list in `flutter_secure_storage` (Keystore/Keychain, encrypted at rest) via a small `SecureTabStore`. To avoid an async refactor of the whole tab path, the encrypted list is pre-loaded once in `main()` (one bounded Keystore read, inside the existing ~1.8 s splash buffer) and cached, so `PreferencesService.getSavedTabs()` stays synchronous and `TabsNotifier` is unchanged; the non-sensitive active index stays in SharedPreferences. **Safety:** first run migrates the legacy plaintext list into encrypted storage and wipes the plaintext copy; every path falls back to plaintext so a broken/unavailable Keystore degrades to the old behaviour rather than losing tabs; save failures are logged, not thrown. Added `test/flutter_test_config.dart` to stub the secure-storage channel suite-wide. `secure_tab_store.dart`, `preferences_service.dart`, `main.dart`. **Pending:** physical-device check of cold-start tab restore + persistence (native Keystore path not exercised by unit tests). |

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
| D-27 | Bundled JetBrains Mono (OFL) as a Flutter font asset behind a `jetBrainsMono()` helper; migrated all 36 `GoogleFonts.jetBrainsMono()` call sites (12 files) off the runtime network fetch → no per-screen first-paint flicker, works offline (was O-40). |
| D-28 | Fixed the 4 stale smoke tests (assertion drift, not a network issue): updated `TabsSheet` labels (`TABS`/`GHOST`/`No open tabs`/`CustomScrollView`) and splash wordmark assertions, and added a frame-by-frame `_drainSplash` helper so the mixed timer+animation splash flow drains cleanly. Full suite now **25/25 green** (was +21/−4) (was O-41). |
| D-29 | Rebuild-scope hygiene (was O-06/O-07): `BrowserView` now `.select`s a structural signature (ids + url-empty + activeIndex) so the webview `Stack` no longer rebuilds on every url/title tick; `Mainscreen` swapped its full `tabsProvider`/`ghostTabsProvider`/`bookmarksProvider` watches for derived `tabCountProvider` + `isCurrentUrlBookmarkedProvider`. *(Reduces UI-thread rebuilds; impact to be confirmed by an Android `--profile` pass, per the perf caveat.)* |


### Merged to `master` — Settings & Downloads Redesign
| ID | Item (issue → approach taken) |
|----|-------------------------------|
| O-03 / R-03 | **O-03 / R-03**: Resolved excessive Android storage permissions. Configured `flutter_downloader` to use `saveInPublicStorage: true` for Android 10+ (using MediaStore), and capped `WRITE_EXTERNAL_STORAGE` to `maxSdkVersion="28"`. Users can find their files without the app demanding broad storage permissions. |
| O-56 | **O-56**: Handled permission blindspots for downloads. Configured downloads to silently fall back and continue seamlessly even if the user denies notification permissions, preventing broken UX. |
| O-33 | **O-33**: Deleted `settings_screen.dart` entirely. Consolidated Theme, Search Engine, and Privacy settings back into an Opera GX-style, high-performance responsive `mira_drawer.dart` utilizing `LayoutBuilder` for desktop/mobile fluid layout. |
| D-36 | **Download UI Performance**: Implemented `cacheWidth: 100` trick for image thumbnails in the `DownloadsScreen` `ListView.builder`, keeping the list buttery smooth without memory overhead. |
| D-37 | **Downloads Orphan Trap**: Plugged the `savePage` storage leak. Offline HTML pages bypassing the download manager are now manually tracked and deleted during a "Clear History (with files)" operation. |
| D-38 | **Native DB Lock Guardrail**: `flutter_downloader` `remove()` calls are now chunked in batches of 25 during `clearHistory` to prevent DDOS-ing the native SQLite lock queue. |

### Verified already-fixed (found resolved during audit triage — no action)
- O-08: desktop find bar already injects its JS library **once per open** behind the `_libraryInjected` flag (`desktop_find_bar.dart:197`), then sends only the command per keystroke; `_close()` resets the flag. The issue text pointed at a stale line (193) — no per-keystroke re-injection occurs.
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
- O-09: `tab_notifier` does **not** persist on every url/title event — `updateUrl`/`updateTitle` route through a 500 ms `_scheduleSave()` debounce; only discrete actions (`addTab`/`closeTab`/`switchTab`/`reorderTab`/`nuke`) write immediately. Resolved by existing design. (The same debounce was the *risk* tracked by O-11 — pending write lost on OS kill — now fixed, D-33.)

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
| O-53 (AdBlock Serialization Jank) | **FALSE ALARM / INTENTIONAL. The synchronous `initialSettings` injection is necessary to guarantee 100% ad-blocking on byte zero. Deferring it asynchronously caused ad-leaks and introduced an artificial 300ms TTFB delay. The 70ms initialization cost is an intentional security/privacy tradeoff.** |
| O-54 (Keyboard Resize Thrashing) | **FALSE ALARM. Setting `resizeToAvoidBottomInset = false` destroys core browser UX. The OS keyboard would paint over the webview, making text fields invisible and breaking scrollability. We must eat the Hybrid Composition rebuild cost here.** |
| O-64 (MRU Set Equality) | **ALREADY FIXED. Code review verified that `if (_mruSet.isNotEmpty && _mruSet.last == tabId) return;` was already natively present in the `HibernationNotifier` codebase. No action needed.** |
