# MIRA AdBlock — Architecture Plan
**Mode: Software Architect | Source: DDG Tracker Radar + flutter_inappwebview ContentBlocker API**
**v2 — Post-Validator Audit**

---

## 1. Executive Summary

MIRA will replicate DuckDuckGo's tracker-blocking model using their open-source Tracker Data Standard (TDS) as the rule source and `flutter_inappwebview`'s `ContentBlocker` API for enforcement. The integration slots into the existing `BrowserEngineConfig → updateSettings()` flow — the same pathway used for dark mode, desktop mode, and camera/location permissions — with no engine rebuild required.

**Default state:** Ad block ON for all users out of the box (matches DDG's default).

---

## 2. Research: How DuckDuckGo Does It

### 2.1 The Data Source — Tracker Data Standard (TDS)

DDG's blocking list is the **Tracker Radar** dataset compiled into `tds.json`. It covers ~3,700 tracker entities sourced from crawling the top 10M websites.

```json
{
  "trackers": {
    "doubleclick.net": {
      "domain": "doubleclick.net",
      "owner": { "name": "Google LLC", "displayName": "Google" },
      "prevalence": 0.62,
      "default": "block",
      "categories": ["Advertising"],
      "rules": [
        {
          "rule": "doubleclick\\.net\\/instream\\/ad_status",
          "action": "ignore"
        }
      ]
    }
  },
  "entities":  { "Google LLC": { "domains": ["doubleclick.net"] } },
  "domains":   { "doubleclick.net": "Google LLC" },
  "cnames":    { "metrics.example.com": "tracker.thirdparty.com" }
}
```

Key fields:
- `default: "block"` → block all third-party requests to this domain
- `default: "ignore"` → allow (tracker is catalogued but not blocked by default)
- `rules` → URL-level exemptions within a blocked domain; `action: "ignore"` means "do not block this specific path"
- `cnames` → CNAME-cloaking bypass map (requires DNS resolution — Phase 3 only)

Live CDN URL:
```
https://raw.githubusercontent.com/duckduckgo/tracker-blocklists/main/web/tds.json
```

### 2.2 iOS: WKContentRuleList (Declarative)

DDG converts TDS into WebKit's static content blocker JSON format, compiles it via `WKContentRuleListStore`, and attaches it to the `WKWebView`. `flutter_inappwebview`'s `ContentBlocker` API is a direct Dart wrapper around this — MIRA's implementation maps 1:1 to DDG's iOS approach.

### 2.3 Android: shouldInterceptRequest (Imperative)

DDG Android overrides `WebViewClient.shouldInterceptRequest()`, evaluating each request against the TDS at runtime. `flutter_inappwebview` does the same — ContentBlocker rules are evaluated via a custom `shouldInterceptRequest` on Android.

| Platform | Mechanism | Rule Limit | Notes |
|---|---|---|---|
| iOS/macOS | WKContentRuleList (native compile) | ~50k–150k | Fastest; hardware-accelerated |
| Android | shouldInterceptRequest (Dart eval) | ~3k practical | Every request checked sequentially; latency grows with rule count |

**Design constraint:** Keep bundled rule count under 3,000 to avoid perceptible intercept latency on Android.

### 2.4 ContentBlocker API — Cross-Platform Fields

| Field | iOS | Android | Notes |
|---|---|---|---|
| `urlFilter` | ✅ | ✅ | Regex matched against full request URL |
| `loadType` | ✅ | ✅ | `FIRST_PARTY` / `THIRD_PARTY` |
| `ifDomain` / `unlessDomain` | ✅ | ✅ | Per-domain scoping |
| `resourceType` | ✅ | ⚠️ | Partially supported on Android |
| `loadContext` / `ifFrameUrl` | ✅ | ❌ | iOS-only |

Action types:
- `BLOCK` — stops the request ✅ both platforms
- `IGNORE_PREVIOUS_RULES` — exempts this request from earlier rules ✅ both platforms
- `CSS_DISPLAY_NONE` — hides DOM elements via CSS selector ✅ both platforms
- `BLOCK_COOKIES` / `MAKE_HTTPS` — iOS/macOS only

**Critical ordering rule (corrected):** `BLOCK` entries must appear **before** the `IGNORE_PREVIOUS_RULES` entries that exempt them. WebKit's `IGNORE_PREVIOUS_RULES` action cancels rules that already triggered at **lower array indices** — rules that appeared before it. For an exemption to cancel a block, the BLOCK rule must be at index N and the IGNORE_PREVIOUS_RULES rule must be at index N+something.

Concrete example for `doubleclick.net`:
```
Index 0: BLOCK  urlFilter="doubleclick\.net"                     ← catches all requests
Index 1: IGNORE urlFilter="doubleclick\.net\/instream\/ad_status" ← cancels index 0 for this path
```
A request to `doubleclick.net/instream/ad_status` triggers index 0 (BLOCK) then index 1 (IGNORE_PREVIOUS_RULES cancels it) → allowed. Any other path triggers only index 0 → blocked.

### 2.5 Dynamic Update (Key Finding)

`flutter_inappwebview` supports updating content blockers at runtime without rebuilding the WebView widget:
```dart
await controller.setSettings(
  settings: InAppWebViewSettings(contentBlockers: newRules),
);
await controller.reload();
```

The existing `updateSettings()` → `reload()` flow already used for desktop mode handles this cleanly.

---

## 3. Architecture Overview

### 3.1 Design Decisions

**Engine abstraction boundary:** `BrowserEngineConfig` is the contract between MIRA's core and any engine. Putting `flutter_inappwebview`'s `ContentBlocker` type in this contract would couple every engine implementation to the plugin. Instead, a platform-agnostic `AdBlockRule` model lives in core. `InAppWebViewEngine` converts it to `ContentBlocker` internally — the plugin type never crosses the shell boundary.

**All-tabs orchestration belongs in `mainscreen.dart`:** `applyMainScreenWebViewSettings` applies settings to the active engine only — its existing responsibility. The all-tabs loop for ad block toggle lives in `mainscreen.dart`'s `_applyAdBlockToAllTabs()` method, where all required providers are already imported.

**Every `applyMainScreenWebViewSettings` call must carry adblock state:** When the user changes location or camera permission, `applyMainScreenWebViewSettings` rebuilds the config and calls `updateSettings`. If `adBlockRules` is not included every time, that call silently clears the content blockers on the active tab. The function always reads `isAdBlockEnabled` and includes the current rules in every config it builds.

### 3.2 Data Flow

```
DDG Tracker Radar (tds.json)
        │
        ▼  [offline — run once per DDG release]
tools/generate_adblock_rules.py
        │
        ▼
assets/adblock/content_blockers.json   (~1,500–2,500 rules, committed to repo)
        │
        ▼  [app startup — main.dart]
AdBlockService.loadRules()             (parse JSON → List<AdBlockRule>, cached statically)
        │
        ▼
adBlockRulesProvider                   (FutureProvider<List<AdBlockRule>>)

── On toggle ──────────────────────────────────────────────────────────────────

SecurityNotifier.toggleAdBlock(bool)   (updates state + persists to PreferencesService)
        │
        ▼  [mainscreen.dart securityProvider listener]
_applyAdBlockToAllTabs(bool enabled)
        │
        ├─ await adBlockRulesProvider.future  → List<AdBlockRule>
        ├─ build BrowserEngineConfig(adBlockRules: rules)
        ├─ [normal tabs] ref.read(browserEngineProvider(tab.id)).updateSettings(config) + reload()
        └─ [ghost tabs]  ref.read(browserEngineProvider(tab.id)).updateSettings(config) + reload()

── On new tab creation ────────────────────────────────────────────────────────

browserEngineProvider(tabId)
        │
        ├─ reads securityProvider.isAdBlockEnabled
        ├─ reads adBlockRulesProvider.valueOrNull (cache is warm)
        └─ InAppWebViewEngine(isPrivate: isGhost, adBlockRules: rules)
                │
                └─ _contentBlockers set at construction → applied in buildWidget initialSettings
```

### 3.3 Provider Dependency Graph

```
adBlockRulesProvider  (FutureProvider<List<AdBlockRule>>)
    └─ awaited by applyMainScreenWebViewSettings (for every call)
    └─ awaited by _applyAdBlockToAllTabs (mainscreen.dart)
    └─ read (valueOrNull) by browserEngineProvider at engine-creation time

securityProvider  (StateNotifierProvider<SecurityNotifier, SecurityState>)
    └─ listened to by mainscreen.dart (isAdBlockEnabled change → _applyAdBlockToAllTabs)
    └─ read by applyMainScreenWebViewSettings
    └─ read by browserEngineProvider

browserEngineProvider(tabId)  (Provider.family<BrowserEngine, String> — non-nullable)
    └─ read per-tab in _applyAdBlockToAllTabs
```

---

## 4. Files To Create

### 4.1 `tools/generate_adblock_rules.py`

Offline script. Run whenever DDG publishes a new TDS. Output is committed to the repo.

```python
#!/usr/bin/env python3
"""
Generates MIRA adblock rules from DDG Tracker Radar TDS.

Usage:
  python tools/generate_adblock_rules.py
  python tools/generate_adblock_rules.py --local path/to/tds.json

Output: assets/adblock/content_blockers.json
License: DDG Tracker Radar is Apache 2.0
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

TDS_URL = (
    "https://raw.githubusercontent.com/duckduckgo/tracker-blocklists"
    "/main/web/tds.json"
)
MIN_PREVALENCE = 0.0001
OUT_PATH = Path("assets/adblock/content_blockers.json")


def escape_domain(domain: str) -> str:
    # Anchored pattern: matches domain and its subdomains, not suffix matches.
    # e.g. "analytics.com" matches "analytics.com/path" and "sub.analytics.com/path"
    # but NOT "fakeanalytics.com".
    return r"(^|\.)" + re.escape(domain) + r"(/|$|[/?#])"


def build_rules(tds: dict) -> list[dict]:
    rules = []

    for domain, tracker in tds["trackers"].items():
        if tracker.get("default") != "block":
            continue
        if tracker.get("prevalence", 0) < MIN_PREVALENCE:
            continue

        escaped = escape_domain(domain)

        # --- BLOCK rule FIRST (lower index) ---
        # IGNORE_PREVIOUS_RULES (below) can only cancel rules at lower indices.
        rules.append({
            "trigger": {
                "urlFilter": escaped,
                "loadType": ["THIRD_PARTY"],
            },
            "action": {"type": "BLOCK"},
        })

        # --- Exception rules AFTER (higher index) ---
        # Each IGNORE_PREVIOUS_RULES fires after the BLOCK above and cancels it
        # for requests that match the specific path.
        for rule in tracker.get("rules", []):
            if rule.get("action") == "ignore":
                rules.append({
                    "trigger": {
                        "urlFilter": rule["rule"],
                        "loadType": ["THIRD_PARTY"],
                    },
                    "action": {"type": "IGNORE_PREVIOUS_RULES"},
                })

    return rules


def main():
    if "--local" in sys.argv:
        idx = sys.argv.index("--local")
        tds = json.loads(Path(sys.argv[idx + 1]).read_text())
        print("Reading local TDS...")
    else:
        print(f"Fetching TDS from {TDS_URL} ...")
        with urllib.request.urlopen(TDS_URL) as resp:
            tds = json.loads(resp.read())

    rules = build_rules(tds)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(rules, separators=(",", ":")))

    blocked = sum(1 for t in tds["trackers"].values() if t.get("default") == "block")
    print(f"Generated {len(rules)} rules covering {blocked} domains → {OUT_PATH}")


if __name__ == "__main__":
    main()
```

### 4.2 `assets/adblock/content_blockers.json`

Pre-compiled output of the script above. Committed to the repo. Example structure (minified in production):

```json
[
  {
    "trigger":{"urlFilter":"(^|\\.)doubleclick\\.net(/|$|[/?#])","loadType":["THIRD_PARTY"]},
    "action":{"type":"BLOCK"}
  },
  {
    "trigger":{"urlFilter":"doubleclick\\.net\\/instream\\/ad_status","loadType":["THIRD_PARTY"]},
    "action":{"type":"IGNORE_PREVIOUS_RULES"}
  },
  {
    "trigger":{"urlFilter":"(^|\\.)google-analytics\\.com(/|$|[/?#])","loadType":["THIRD_PARTY"]},
    "action":{"type":"BLOCK"}
  },
  {
    "trigger":{"urlFilter":"google-analytics\\.com\\/analytics\\.js","loadType":["THIRD_PARTY"]},
    "action":{"type":"IGNORE_PREVIOUS_RULES"}
  }
]
```

Note: BLOCK always precedes any IGNORE_PREVIOUS_RULES for the same domain.

### 4.3 `lib/core/services/adblock_service.dart`

Returns platform-agnostic `AdBlockRule` objects — no `flutter_inappwebview` import here.

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

class AdBlockService {
  static List<AdBlockRule>? _cache;

  static Future<List<AdBlockRule>> loadRules() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(
      'assets/adblock/content_blockers.json',
    );
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
  }

  /// Synchronous read of the pre-warmed cache.
  /// Returns the cached rules if main.dart's pre-warm has run, otherwise empty.
  /// Use this in Provider bodies where async resolution would cause a race.
  static List<AdBlockRule> loadRulesSync() => _cache ?? const <AdBlockRule>[];

  static AdBlockRule _fromJson(Map<String, dynamic> json) {
    final trigger = json['trigger'] as Map<String, dynamic>;
    final action  = json['action']  as Map<String, dynamic>;
    return AdBlockRule(
      urlFilter: trigger['urlFilter'] as String,
      isBlock: (action['type'] as String) == 'BLOCK',
    );
  }
}
```

### 4.4 `lib/core/providers/adblock_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/adblock_service.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

final adBlockRulesProvider = FutureProvider<List<AdBlockRule>>((ref) {
  return AdBlockService.loadRules();
});
```

---

## 5. Files To Modify

### 5.1 `lib/core/entities/security_entity.dart`

Add `isAdBlockEnabled` defaulting to `true`:

```dart
class SecurityState {
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;
  final bool isAdBlockEnabled;   // NEW

  SecurityState({
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
    this.isAdBlockEnabled = true,  // NEW — on by default
  });

  SecurityState copyWith({
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
    bool? isAdBlockEnabled,   // NEW
  }) {
    return SecurityState(
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked:   isCameraBlocked   ?? this.isCameraBlocked,
      isDesktopMode:     isDesktopMode     ?? this.isDesktopMode,
      isAdBlockEnabled:  isAdBlockEnabled  ?? this.isAdBlockEnabled,  // NEW
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityState &&
          other.isLocationBlocked == isLocationBlocked &&
          other.isCameraBlocked   == isCameraBlocked   &&
          other.isDesktopMode     == isDesktopMode     &&
          other.isAdBlockEnabled  == isAdBlockEnabled); // NEW

  @override
  int get hashCode =>
      Object.hash(isLocationBlocked, isCameraBlocked, isDesktopMode, isAdBlockEnabled); // NEW
}
```

### 5.2 `lib/core/services/preferences_service.dart`

`SecurityNotifier` already routes all persistence through `PreferencesService`. Add the adblock key and accessors:

```dart
// Add to the "KEYS" section:
static const _keyAdBlock = 'adblock_enabled';

// Add to "SECURITY MODES" section:
bool getAdBlockEnabled() => _prefs.getBool(_keyAdBlock) ?? true;
Future<void> setAdBlockEnabled(bool value) async =>
    await _prefs.setBool(_keyAdBlock, value);
```

### 5.3 `lib/core/notifiers/security_notifier.dart`

Add `toggleAdBlock()` and load the persisted value in `_loadSettings()`:

```dart
void _loadSettings() {
  state = SecurityState(
    isLocationBlocked: _prefs.getLocationBlock(),
    isCameraBlocked:   _prefs.getCameraBlock(),
    isDesktopMode:     _prefs.getDesktopMode(),
    isAdBlockEnabled:  _prefs.getAdBlockEnabled(),  // NEW
  );
}

void toggleAdBlock(bool value) {    // NEW
  state = state.copyWith(isAdBlockEnabled: value);
  _prefs.setAdBlockEnabled(value);
}
```

### 5.4 `lib/core/services/browser_engine_blueprints.dart`

Add `AdBlockRule` model and `adBlockRules` field to `BrowserEngineConfig`. No `flutter_inappwebview` import — types stay platform-agnostic:

```dart
// Add before BrowserEngineConfig:
class AdBlockRule {
  final String urlFilter;
  final bool isBlock;  // true = BLOCK, false = IGNORE_PREVIOUS_RULES
  const AdBlockRule({required this.urlFilter, required this.isBlock});
}

class BrowserEngineConfig {
  final bool isDesktopMode;
  final bool isDarkMode;
  final bool isCameraBlocked;
  final bool isLocationBlocked;
  final List<AdBlockRule> adBlockRules;   // NEW

  const BrowserEngineConfig({
    required this.isDesktopMode,
    required this.isDarkMode,
    required this.isCameraBlocked,
    required this.isLocationBlocked,
    this.adBlockRules = const [],         // NEW — empty = no blocking
  });
}
```

### 5.5 `lib/shell/browser/in_app_webview_engine.dart`

Three changes:

**Add constructor parameter** and convert `AdBlockRule` → `ContentBlocker` internally:

```dart
List<ContentBlocker> _contentBlockers;

InAppWebViewEngine({
  bool isPrivate = false,
  List<AdBlockRule> adBlockRules = const [],  // NEW
}) : _isPrivate = isPrivate,
     _contentBlockers = _toContentBlockers(adBlockRules);

static List<ContentBlocker> _toContentBlockers(List<AdBlockRule> rules) {
  return rules.map((r) => ContentBlocker(
    trigger: ContentBlockerTrigger(
      urlFilter: r.urlFilter,
      loadType: [ContentBlockerTriggerLoadType.THIRD_PARTY],
    ),
    action: ContentBlockerAction(
      type: r.isBlock
          ? ContentBlockerActionType.BLOCK
          : ContentBlockerActionType.IGNORE_PREVIOUS_RULES,
    ),
  )).toList(growable: false);
}
```

**In `updateSettings()`** — store and apply:

```dart
@override
Future<void> updateSettings(BrowserEngineConfig config) async {
  _isCameraBlocked   = config.isCameraBlocked;
  _isLocationBlocked = config.isLocationBlocked;
  _contentBlockers   = _toContentBlockers(config.adBlockRules);  // NEW

  final settings = InAppWebViewSettings(
    forceDark: config.isDarkMode ? ForceDark.ON : ForceDark.OFF,
    algorithmicDarkeningAllowed: config.isDarkMode,
    userAgent: desktopModeUserAgent(
      isDesktop: !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
      desktopModeOn: config.isDesktopMode,
    ),
    preferredContentMode: config.isDesktopMode
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.MOBILE,
    geolocationEnabled: !config.isLocationBlocked,
    contentBlockers: _contentBlockers,   // NEW
  );

  await _controller?.setSettings(settings: settings);
}
```

**In `buildWidget()`** — apply at widget creation (already correct via `_contentBlockers` field):

```dart
initialSettings: InAppWebViewSettings(
  incognito:                   _isPrivate,
  transparentBackground:       true,
  useShouldOverrideUrlLoading: true,
  useOnDownloadStart:          true,
  geolocationEnabled:          !_isLocationBlocked,
  contentBlockers:             _contentBlockers,   // NEW
),
```

### 5.6 `lib/core/services/database_providers.dart`

Pass the current adblock rules at engine-creation time so **new tabs always start with the correct blockers**.

Use `AdBlockService.loadRulesSync()` — not `adBlockRulesProvider.valueOrNull`. A `FutureProvider` won't have resolved its `AsyncValue` synchronously on the first read (even when the cache is warm, the async function still returns a `Future` that resolves on the next microtask). `loadRulesSync()` reads the static cache directly, bypassing Riverpod's scheduler entirely.

```dart
import 'package:mira/core/services/adblock_service.dart';    // loadRulesSync()
import 'package:mira/core/notifiers/security_notifier.dart';

final browserEngineProvider = Provider.family<BrowserEngine, String>((ref, tabId) {
  final isGhostTab = ref.watch(ghostTabsProvider.select(
    (s) => s.tabs.any((t) => t.id == tabId),
  ));

  // Use loadRulesSync() — not adBlockRulesProvider.valueOrNull.
  // The cache is populated by main.dart's pre-warm before runApp(),
  // so this always returns the full rule list at engine-creation time.
  final security = ref.read(securityProvider);
  final adBlockRules = security.isAdBlockEnabled
      ? AdBlockService.loadRulesSync()
      : const <AdBlockRule>[];

  final engine = InAppWebViewEngine(
    isPrivate: isGhostTab,
    adBlockRules: adBlockRules,
  );

  ref.onDispose(() => engine.dispose());
  return engine;
});
```

### 5.7 `lib/pages/main_screen/main_screen_security.dart`

**New imports required:**

```dart
import 'package:mira/core/providers/adblock_provider.dart';  // adBlockRulesProvider
import 'package:mira/core/services/browser_engine_blueprints.dart'; // AdBlockRule
```

**Update `applyMainScreenWebViewSettings`** — always include current adblock rules in the config. Any call that omits them would silently clear content blockers on the active tab:

```dart
Future<void> applyMainScreenWebViewSettings(
  WidgetRef ref, {
  bool forceReload = false,
}) async {
  final engine = ref.read(browserChromeProvider).engine;
  if (engine == null) return;

  final theme         = ref.read(themeProvider);
  final securityState = ref.read(securityProvider);

  // Always resolve adblock state — omitting it would clear content blockers
  // on the active tab whenever location/camera/desktop mode is toggled.
  final List<AdBlockRule> adBlockRules;
  if (securityState.isAdBlockEnabled) {
    adBlockRules = await ref.read(adBlockRulesProvider.future);
  } else {
    adBlockRules = const [];
  }

  final config = BrowserEngineConfig(
    isDesktopMode:     securityState.isDesktopMode,
    isDarkMode:        theme.mode == ThemeMode.dark,
    isCameraBlocked:   securityState.isCameraBlocked,
    isLocationBlocked: securityState.isLocationBlocked,
    adBlockRules:      adBlockRules,   // NEW
  );

  try {
    await engine.updateSettings(config);
    if (forceReload) await engine.reload();
  } catch (e) {
    debugPrint('MIRA: Failed to update engine settings: $e');
  }
}
```

**Add Ad Block toggle to `_SecurityPanel`** (after the Desktop Mode row):

```dart
const SizedBox(height: 8),
Divider(height: 1, color: textColor.withOpacity(0.08)),
const SizedBox(height: 8),

Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(
    'PRIVACY',
    style: GoogleFonts.jetBrainsMono(
      fontSize: 10,
      color: textColor.withOpacity(0.35),
      letterSpacing: 2.5,
    ),
  ),
),

_PermissionRow(
  icon: Icons.shield_outlined,
  label: 'Ad & Tracker Block',
  sublabel: security.isAdBlockEnabled ? 'Active' : 'Off',
  isBlocked: false,
  isSwitch: true,
  switchValue: security.isAdBlockEnabled,
  textColor: textColor,
  accentColor: theme.primaryColor,
  onToggle: (val) {
    // toggleAdBlock updates securityProvider state.
    // mainscreen.dart's listener picks up the change and calls
    // _applyAdBlockToAllTabs — no direct engine call needed here.
    ref.read(securityProvider.notifier).toggleAdBlock(val);
  },
),
```

### 5.8 `lib/pages/mainscreen.dart`

**New imports required:**

```dart
import 'package:mira/core/services/database_providers.dart';  // browserEngineProvider
import 'package:mira/core/providers/adblock_provider.dart';   // adBlockRulesProvider
```

**Add `_applyAdBlockToAllTabs` method to `_MainscreenState`:**

```dart
Future<void> _applyAdBlockToAllTabs(bool enabled) async {
  final List<AdBlockRule> adBlockRules = enabled
      ? await ref.read(adBlockRulesProvider.future)
      : const <AdBlockRule>[];

  // Guard after the first await — widget may have unmounted while
  // the future was resolving (e.g. user force-closed the app).
  if (!mounted) return;

  final theme    = ref.read(themeProvider);
  final security = ref.read(securityProvider);

  final config = BrowserEngineConfig(
    isDesktopMode:     security.isDesktopMode,
    isDarkMode:        theme.mode == ThemeMode.dark,
    isCameraBlocked:   security.isCameraBlocked,
    isLocationBlocked: security.isLocationBlocked,
    adBlockRules:      adBlockRules,
  );

  final allTabs = [
    ...ref.read(tabsProvider).tabs,
    ...ref.read(ghostTabsProvider).tabs,
  ];

  for (final tab in allTabs) {
    if (!mounted) return;  // guard each iteration — reload() is also async
    try {
      final engine = ref.read(browserEngineProvider(tab.id));
      await engine.updateSettings(config);
      await engine.reload();
    } catch (e) {
      debugPrint('MIRA: AdBlock update failed for tab ${tab.id}: $e');
    }
  }
}
```

**Extend the existing `securityProvider` listener in `build()`:**

```dart
ref.listen(securityProvider, (prev, next) {
  if (prev?.isDesktopMode != next.isDesktopMode) {
    applyMainScreenWebViewSettings(ref, forceReload: true);
  }
  if (prev?.isAdBlockEnabled != next.isAdBlockEnabled) {  // NEW
    unawaited(_applyAdBlockToAllTabs(next.isAdBlockEnabled));
  }
});
```

> **Fire-and-forget caveat:** Both `applyMainScreenWebViewSettings` and `_applyAdBlockToAllTabs` are called without `await` from this listener (the listener callback is `void Function(T?, T)` — `await` is not possible). This is safe for Phase 1 because the rule cache is pre-warmed before `runApp`, so the `adBlockRulesProvider.future` resolves in the next microtask with no real async latency. If an error occurs inside either function, it is caught and `debugPrint`-ed, not surfaced to the user.

### 5.9 `lib/main.dart`

Pre-warm the rule cache before `runApp` so `adBlockRulesProvider.valueOrNull` is non-null by the time the first tab engine is created:

```dart
// After WidgetsFlutterBinding.ensureInitialized(), before runApp():
await AdBlockService.loadRules(); // parse once, cache for the session
```

### 5.10 `pubspec.yaml`

```yaml
flutter:
  assets:
    - assets/adblock/content_blockers.json
```

---

## 6. Limitations & Known Gaps

| Limitation | Impact | Phase |
|---|---|---|
| **CNAME cloaking** | First-party subdomains proxying third-party trackers bypass rules entirely | Phase 3 |
| **Surrogate scripts** | Sites structurally dependent on tracker APIs may break without a replacement shim | Phase 3 |
| **Android rule-count latency** | Rules evaluated per-request in Dart; >3k rules adds measurable intercept delay | Keep rules under 3k; benchmark on low-end devices |
| **`loadType: THIRD_PARTY` on Android** | Android's `shouldInterceptRequest` may not honour `THIRD_PARTY` filtering uniformly | Test both platforms; fall back to URL-only matching if needed |
| **Static list** | Bundled rules frozen at build time; new trackers uncovered until next release | Phase 2: OTA updates |
| **All-tabs reload** | Toggling ad block reloads every open tab — user loses scroll position | Acceptable for a privacy toggle; consider a Snackbar warning |
| **First-party trackers** | `THIRD_PARTY`-only filtering means trackers served same-origin bypass blocking | By design — blocking first-party assets would break the site |
| **Exception rules limited to `action: "ignore"`** | TDS rules with other action types are silently dropped by the script | Acceptable for MVP; no other action type affects blocking behaviour |

---

## 7. Implementation Phases

### Phase 1 — MVP (This Sprint)

- [ ] Run `tools/generate_adblock_rules.py` → inspect output count and sample rules → commit `assets/adblock/content_blockers.json`
- [ ] Create `lib/core/services/adblock_service.dart`
- [ ] Create `lib/core/providers/adblock_provider.dart`
- [ ] Modify `lib/core/entities/security_entity.dart` — add `isAdBlockEnabled`
- [ ] Modify `lib/core/services/preferences_service.dart` — add `_keyAdBlock`, `getAdBlockEnabled()`, `setAdBlockEnabled()`
- [ ] Modify `lib/core/notifiers/security_notifier.dart` — add `toggleAdBlock()`, load persisted value in `_loadSettings()`
- [ ] Modify `lib/core/services/browser_engine_blueprints.dart` — add `AdBlockRule` model + `adBlockRules` field
- [ ] Modify `lib/shell/browser/in_app_webview_engine.dart` — constructor param, `_toContentBlockers()`, `buildWidget`, `updateSettings`
- [ ] Modify `lib/core/services/database_providers.dart` — pass `adBlockRules` at engine creation
- [ ] Modify `lib/pages/main_screen/main_screen_security.dart` — update `applyMainScreenWebViewSettings` + PRIVACY section UI
- [ ] Modify `lib/pages/mainscreen.dart` — add `_applyAdBlockToAllTabs()` + listener branch
- [ ] Modify `lib/main.dart` — pre-warm cache
- [ ] Modify `pubspec.yaml` — register asset

### Phase 2 — OTA List Updates (v1.1)

- [ ] `AdBlockUpdateService`: on launch, check if bundled rules are >7 days old
- [ ] Fetch fresh TDS from DDG CDN; parse and convert in a background isolate
- [ ] SHA-256 integrity check before applying
- [ ] `AdBlockService.loadRules()` prefers local cached version over bundled asset
- [ ] Show subtle "Tracker list updated" toast on refresh

### Phase 3 — Advanced Blocking (v2.0)

- [ ] CNAME cloaking bypass (DNS resolver + `cnames` map from TDS)
- [ ] Surrogate script injection for top-10 broken tracker APIs (`ga.js`, `fbevents.js`)
- [ ] Per-site exception list — user can whitelist a domain from the security panel
- [ ] Blocked tracker count per tab (visible in security panel)
- [ ] Tracker category breakdown (Advertising / Analytics / Fingerprinting)

---

## 8. File Change Summary

```
NEW   tools/generate_adblock_rules.py
NEW   assets/adblock/content_blockers.json
NEW   lib/core/services/adblock_service.dart
NEW   lib/core/providers/adblock_provider.dart

MOD   lib/core/entities/security_entity.dart             + isAdBlockEnabled
MOD   lib/core/services/preferences_service.dart         + adblock key + getter/setter
MOD   lib/core/notifiers/security_notifier.dart          + toggleAdBlock() + _loadSettings()
MOD   lib/core/services/browser_engine_blueprints.dart   + AdBlockRule model + adBlockRules field
MOD   lib/shell/browser/in_app_webview_engine.dart       + constructor param, _toContentBlockers, buildWidget, updateSettings
MOD   lib/core/services/database_providers.dart          + pass adBlockRules at engine creation
MOD   lib/pages/main_screen/main_screen_security.dart    + applyMainScreenWebViewSettings update + PRIVACY section UI
MOD   lib/pages/mainscreen.dart                          + _applyAdBlockToAllTabs() + listener branch
MOD   lib/main.dart                                      + AdBlockService.loadRules() pre-warm
MOD   pubspec.yaml                                       + asset entry
```

**Total new files: 4 | Modified files: 10 | Net new Dart LOC: ~140**

---

## 9. Verification Checklist

After Phase 1 implementation, run in order:

1. `flutter pub get` — **required first** after `pubspec.yaml` asset entry is added; `flutter analyze` will fail without it
2. `flutter analyze` — confirm no new errors

Then verify on a physical Android device:

- [ ] `flutter analyze` passes with no new errors
- [ ] App cold start — no crash; first tab builds without any adblock-related exception
- [ ] Open `https://nytimes.com` — ads absent or significantly reduced (visual check; or verify via `adb logcat | grep MIRA` / mitmproxy that `doubleclick.net` requests are blocked)
- [ ] Open a **new** tab after app is loaded — ads also blocked (confirms `database_providers.dart` fix; new engine starts with rules)
- [ ] Toggle Ad Block OFF in security panel — all tabs reload, ads reappear
- [ ] Toggle Ad Block ON — all tabs reload, ads blocked again
- [ ] Toggle location permission — active tab reloads with correct location setting AND ad block still active (confirms `applyMainScreenWebViewSettings` carries adblock rules on every call)
- [ ] Open a ghost tab — blocking works identically (ghost engines also receive rules via `database_providers.dart`)
- [ ] Speed dial (empty URL tab) — no visible change, no crash
- [ ] YouTube — video plays (DDG's IGNORE_PREVIOUS_RULES exemptions work; confirms correct BLOCK-before-IGNORE ordering)
- [ ] App restart — Ad Block toggle state persists (confirms `PreferencesService` persistence)

---

*Sources: [DDG TrackerRadarKit](https://github.com/duckduckgo/TrackerRadarKit) · [tracker-blocklists](https://github.com/duckduckgo/tracker-blocklists) · [tracker-radar DATA_MODEL](https://github.com/duckduckgo/tracker-radar/blob/main/docs/DATA_MODEL.md) · [flutter_inappwebview ContentBlockers](https://inappwebview.dev/docs/webview/content-blockers) · DDG Android Architecture (DeepWiki)*
