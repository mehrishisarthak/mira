# MIRA Mobile (Android / iOS) — UI/UX Report
_Mode 4: UI/UX Specialist | 2026-06-16_

---

## Current State Audit

### What Exists Today

```
┌─────────────────────────────────┐
│ [🔒] [URL TextField       ][★] │  ← AppBar (HARD TO REACH on 6.7" phone)
│       [Tab Count][⋮]           │
│ ════════════════════════════════│  ← LinearProgressIndicator (2px)
│                                 │
│                                 │
│        WEBVIEW CONTENT          │
│                                 │
│                                 │
│                                 │
└─────────────────────────────────┘
```

The menu is a full-page push. Tabs are a modal bottom sheet (80% height, 2-column grid). Ghost mode is buried 3 taps deep in the menu.

---

## Problems Identified

**1. Address bar is at the top — unreachable on large phones**
The average Android flagship in 2026 is 6.5–6.9 inches. On a 6.7" phone, the top of the screen requires a full hand reposition or a grip shift to reach. Apple moved Safari's address bar to the bottom in iOS 15 precisely because of this. Chrome has a bottom address bar option. MIRA has nothing. This is the single most critical ergonomic failure.

**2. Tab count badge shows ghost + normal combined**
`tabCount = normalTabsList.length + ghostTabsList.length`. If the user has 3 normal tabs and 2 ghost tabs, the badge shows "5". Opening the tab sheet reveals 2 separate sections. The count implies one session when there are two. Confusing.

**3. Ghost mode requires 3 taps to activate**
Tap menu → scroll to "New Ghost Tab" → tap. On mobile, that's too buried for a core privacy feature. Ghost mode should be a swipe or a single-tap toggle visible at all times.

**4. Tab sheet is a 2-column grid with no favicons**
The current 2-column grid shows a title, URL, and a dot. No favicon. No screenshot preview. At 2 columns, you get maybe 4 tiles on screen before scrolling. For a user with 10 tabs, this is a scroll hunt with no visual landmarks.

**5. Menu is a full-page push**
Tapping `⋮` navigates to a new route (MiraMenuPage). This is a jarring full-screen transition for what should be a quick-access panel. Back navigation exits the menu — the user loses their place visually. Standard mobile pattern is a slide-up bottom sheet or a popup menu.

**6. Ghost landing page has zero interaction affordance**
The Ghost mode landing screen shows "GHOST PROTOCOL ACTIVE" with a list of what's protected. Zero buttons. Zero call to action. The user has to know to tap the address bar to start browsing. First-time ghost mode users will be confused.

**7. No swipe gestures for navigation**
Back/forward navigation requires tapping a button (in the error screen) or the system back gesture. Standard mobile browser UX: swipe right = go back, swipe left = go forward. Safari does this. Chrome does this. MIRA does not.

**8. No swipe-between-tabs gesture**
Switching tabs requires opening the tab sheet (2 taps). Chrome, Firefox, and Safari all support horizontal swipe on the browser content to switch tabs. This is a high-frequency action being given a high-effort path.

**9. Speed dial is hardcoded and not contextual**
YouTube, Reddit, GitHub, Wikipedia, DuckDuckGo, HackerNews — these are developer defaults. A privacy-focused user's first-open new tab page showing YouTube and Reddit feels misaligned. Speed dial should adapt: show recently visited sites after first week, allow reordering, allow removal.

**10. Progress indicator is 2px at the top — invisible**
`LinearProgressIndicator(minHeight: 2)` at the bottom of the AppBar is nearly invisible. Users frequently don't know a page is still loading. Android Chrome uses a subtle tinted progress bar that's much more visible.

**11. Security icon tap opens a static dialog**
Tapping the lock icon opens an `AlertDialog` with "Connection Secure" text. This is informational only. Industry UX standard (Chrome, Firefox) is to show a bottom sheet with: site permissions, certificate info, and quick-toggle controls for location/camera/mic. MIRA has the toggles — they're buried in the drawer. They should appear here, contextually.

**12. Back-to-home-screen gesture is not discoverable**
When the user has navigated deep into a site and wants to return to the speed dial (new tab), they must hold back or figure out the 2-second press gesture. This behavior isn't communicated anywhere.

**13. Haptics are inconsistent**
`_triggerHaptic` is only called in `_performSearch` and `_handlePop`. Common actions like opening/closing tabs, toggling ghost mode, and tapping speed dial items have no haptic response. On Android, haptics are expected for any consequential action.

**14. Downloads screen empty state is plain text**
"No downloads yet" in muted text. An empty state should communicate what the screen does and give the user a path forward.

---

## Redesign: Bottom-First Architecture

### North Star Layout

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│        WEBVIEW CONTENT          │  ← 90% of screen
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│ [←]  [🔒 example.com    ] [⋮] │  ← BOTTOM BAR (thumb zone)
│      [████░░░░░░░░░░░░░░]      │  ← progress bar (thicker, below bar)
└─────────────────────────────────┘
```

The entire chrome moves to the bottom. The address bar, navigation controls, and action menu are all within thumb reach on any phone size.

---

## Bottom Bar — States

### Idle (page loaded)
```
┌────────────────────────────────────────┐
│ [←]  [🔒 example.com              ] [⋮]│
└────────────────────────────────────────┘
```

### Loading
```
┌────────────────────────────────────────┐
│ [←]  [⟳ example.com              ] [⋮]│
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← 3px progress, themed color
└────────────────────────────────────────┘
```

### Focused (URL editing)
```
┌────────────────────────────────────────┐
│ [×]  [https://www.example.com/full ] [→]│
│  ┌──────────────────────────────────┐  │
│  │ 🕐 example.com (history)         │  │  ← suggestions drawer
│  │ 🔍 "example" — DuckDuckGo       │  │    slides UP from bottom
│  │ ⭐ Bookmarked: Example Page      │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### Ghost Mode (active)
```
┌────────────────────────────────────────┐  ← dark background
│ [←]  [👁 Private browsing        ] [⋮]│  ← red tint, ghost icon
└────────────────────────────────────────┘
```

---

## Tab Management — Swipe Gestures

Replace the 2-column grid sheet with gesture-based tab switching:

### Swipe up from bottom bar = Tab overview
```
┌─────────────────────────────────┐
│  ACTIVE SESSIONS     [+ New]    │
├─────────────────────────────────┤
│ ┌─────────┐  ┌─────────┐       │
│ │[preview]│  │[preview]│       │  ← page screenshots
│ │ YouTube │  │ GitHub  │       │
│ │ ★ active│  │         │       │
│ └─────────┘  └─────────┘       │
│                                 │
│ ┌─────────┐  ┌─────────┐       │
│ │[preview]│  │[preview]│       │
│ │ Reddit  │  │   Wiki  │       │
│ └─────────┘  └─────────┘       │
├─────────────────────────────────┤
│  👁 GHOST  ·  2 private tabs   │  ← ghost section, collapsed by default
└─────────────────────────────────┘
```

**Swipe up on a tab card = close it** (same gesture as iOS multitasking)
**Tap a tab card = switch to it + close the overview**
**Long press tab card = pin / move to ghost**

### Horizontal swipe on webview content
- **Swipe right (≥40% of screen width)** = go back
- **Swipe left (≥40% of screen width, if forward history exists)** = go forward
- Visual indicator: edge glow + arrow that follows finger

### Swipe left/right on BOTTOM BAR
- **Swipe left on bottom bar** = switch to next tab
- **Swipe right on bottom bar** = switch to previous tab
- Visual indicator: small tab title sneak-peek at edge

---

## Ghost Mode — One Tap From Anywhere

Ghost mode must not require a menu dive. Two approaches:

### Option A — Long press on address bar
Long press `[🔒 example.com]` → context menu appears:
```
┌──────────────────────────────────┐
│  Open in Ghost Tab               │
│  Copy URL                        │
│  Share                           │
└──────────────────────────────────┘
```

### Option B — Ghost button always in bottom bar
Add `[👁]` icon between `[←]` and the address bar. Single tap toggles ghost mode with a smooth dark-mode transition animation.

```
[←] [👁] [🔒 example.com        ] [⋮]
         ↑ always visible
```

**Recommendation: Option B.** Ghost mode is a core differentiator. It should be a first-class action, not a menu item.

---

## Security Panel — Replace Static Dialog

Tapping the lock icon currently opens:
```
AlertDialog("Connection Secure", "MIRA verified this site...")
```

Replace with a bottom sheet permission panel:

```
┌─────────────────────────────────┐
│  🔒  example.com                │
│  Connection Secure · TLS 1.3    │
│  ─────────────────────────────  │
│  PERMISSIONS                    │
│  📍 Location          [OFF  ] → │  ← inline toggle
│  🎙 Microphone        [OFF  ] → │
│  📷 Camera            [OFF  ] → │
│  🍪 Cookies                   > │
│  ─────────────────────────────  │
│  View Certificate               │
└─────────────────────────────────┘
```

This puts the security toggles in context — right where the user is thinking about security. Three fewer taps vs going through the drawer.

---

## Speed Dial — Adaptive New Tab Page

### Layout Redesign

Instead of a fixed 6-item `Wrap`, use a responsive grid that evolves with the user:

**First week (new user) — curated defaults:**
```
┌─────────────────────────────────┐
│                                 │
│    Good morning.                │  ← time-aware greeting
│    Your web, your rules.        │
│                                 │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │ [YT] │ │ [GH] │ │ [RD] │   │
│  │  YT  │ │  GH  │ │  RD  │   │
│  └──────┘ └──────┘ └──────┘   │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │ [🔍] │ │ [🌐] │ │ [+]  │   │
│  │  DDG  │ │ Wiki │ │ Add  │   │
│  └──────┘ └──────┘ └──────┘   │
│                                 │
│  ──── Recent History ─────     │  ← after first visit
│  > example.com · 2 mins ago    │
└─────────────────────────────────┘
```

**After usage (returning user) — recents surface:**
```
│  ── TOP SITES ──────────────────│
│  [favicon] Github · visited 12× │
│  [favicon] Reddit · visited 8×  │
│  [favicon] NYT · visited 5×     │
│  ─────────────────────────────  │
│  ── PINNED ─────────────────── │
│  [YT] [DDG] [Wiki] [+]         │
```

Speed dial items are:
- **Favicon** from actual site (not Flutter icon)
- **Long-pressable** → pin / remove / edit label
- **[+] tile** always last → opens "Add site" sheet

---

## Ghost Landing Page — Give It a Job

Current ghost landing: information screen with no interaction.

Redesign:
```
┌─────────────────────────────────┐
│                                 │
│           👁                    │
│    GHOST PROTOCOL               │
│         ACTIVE                  │
│                                 │
│  ✓ History not saved            │
│  ✓ Cookies cleared on exit      │
│  ✓ No traces left               │
│                                 │
│  ┌─────────────────────────┐    │
│  │  Where do you want      │    │  ← auto-focused search field
│  │  to go?                 │    │     tapping opens keyboard
│  └─────────────────────────┘    │
│                                 │
│  [DuckDuckGo][Brave Search]     │  ← quick-launch buttons
└─────────────────────────────────┘
```

The ghost landing page becomes a launchpad, not a notice board.

---

## Haptic Design System

Every consequential action should have a haptic response. Current state: haptics on search and back only.

| Action | Haptic |
|---|---|
| Tab opened | `lightImpact` |
| Tab closed | `mediumImpact` |
| Ghost mode ON | `heavyImpact` (dramatic, intentional) |
| Ghost mode OFF | `mediumImpact` |
| Bookmark added | `lightImpact` + success pattern |
| Back navigation (webview) | `selectionClick` |
| Speed dial tap | `lightImpact` |
| Swipe-to-close-tab (threshold reached) | `mediumImpact` |
| Download complete (notification-less) | `heavyImpact` |
| Error page shown | none (errors are silent) |

---

## Downloads — Empty State & UX

### Empty State (current: plain text)
```
┌────────────────────────────┐
│                            │
│           ⬇               │  ← large icon, themed color
│                            │
│    No downloads yet        │
│                            │
│  Files you download from   │
│  MIRA appear here.         │
│                            │
│  [Browse the web]          │  ← CTA back to browser
└────────────────────────────┘
```

### Download Tile — Add Progress Ring
Replace `LinearProgressIndicator` inside the subtitle with a circular progress indicator on the leading icon:

```
│ [⬇ 67%]  filename.pdf               │  ← circular indicator wraps icon
│           87 MB · 23 MB/s           │
│           [‖ Pause]  [✕ Cancel]     │
```

---

## Micro-Interactions

| Trigger | Current | Proposed |
|---|---|---|
| Bottom bar tap (URL) | Full keyboard + unfocused state confusion | Keyboard slides up, suggestions drawer rises simultaneously, clear visual state |
| Ghost mode toggle | Instant, silent | 300ms: screen dims, bottom bar shifts dark, ghost icon pulses once |
| Tab close (swipe up) | N/A | Tab card scales down + fades out (120ms ease-in) |
| New tab | Added, sheet closes | Smooth crossfade to new tab's blank state (150ms) |
| Speed dial tap | Instant navigation | 80ms scale bounce on tap, then navigate |
| Download starts | Nothing visible | Bottom bar briefly shows "Downloading..." chip (2s) then fades |
| Page load complete | Progress bar disappears | 200ms fade of progress bar, subtle bounce on favicon |
| Back at root (exit prompt) | Snackbar | Gentle bottom sheet: "Hold to exit MIRA" with a hold animation |

---

## Summary: What Makes This Feel Original

Most browsers copy Chrome. MIRA's mobile advantage is:

1. **Bottom-everything** — the only browser where every control is one-thumb-reachable
2. **Ghost mode as a first-class button** — not a menu item, not hidden — always visible
3. **Gesture-native tab management** — swipe the bar to switch tabs, swipe up to see all, swipe up on a tab to close it
4. **Security panel = permission panel** — tapping the lock does something useful, not just showing a certificate string
5. **Adaptive speed dial** — learns what you visit, surfaces it without being asked
6. **Haptics as a design layer** — every action has physical feedback, the browser feels alive

---

## Priority Implementation Order

| Priority | Change | Effort | Impact |
|---|---|---|---|
| 1 | Move chrome to bottom (bottom bar) | High | Critical |
| 2 | Ghost mode button always visible in bottom bar | Low | High |
| 3 | Security panel → permissions bottom sheet | Medium | High |
| 4 | Swipe bottom bar to switch tabs | Medium | High |
| 5 | Tab overview with screenshots (replace grid sheet) | High | High |
| 6 | Ghost landing page with search field | Low | Medium |
| 7 | Haptic design system | Low | Medium |
| 8 | Adaptive speed dial (favicons + recents) | Medium | Medium |
| 9 | Swipe gestures for back/forward on webview | Medium | Medium |
| 10 | Downloads empty state + progress ring | Low | Low |
