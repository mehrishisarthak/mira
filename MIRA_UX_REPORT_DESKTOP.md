# MIRA Desktop — UI/UX Report
_Mode 4: UI/UX Specialist | 2026-06-16_

---

## Current State Audit

### What Exists Today

```
┌─────────────────────────────────────────────────────────────────┐
│  [Tab 1 ×] [Tab 2 ×] [Tab 3 ×]                    [+]          │  ← 40px tab strip
├──────────────────────────────────────────────────────────────────┤
│  [←][→][↺]  [🔒 https://example.com              ★]  [⋮]      │  ← toolbar row
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│                       WEBVIEW CONTENT                            │
│                                                                  │
│                                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                              [Find in Page ▲] ← bottom overlay
```

### Problems Identified

**1. No vertical sidebar — the biggest structural gap**
The horizontal tab strip fails at 5+ tabs. Each chip is 212px fixed-width. At 1200px window width, you get 5 tabs before overflow. Chrome has this problem. Arc solved it with a sidebar. MIRA's north star is a sidebar. This is the single most important missing piece.

**2. Tabs have no favicons**
Every tab chip shows text only. At 5+ tabs, all chips show truncated titles that look identical. Users cannot scan to find their tab — they must read every one. Favicons reduce tab-finding time by 60–80% (Fitts' Law — you're scanning icons, not reading text).

**3. Find bar is at the bottom — users look top-right**
Every major browser (Chrome, Firefox, Edge, Safari) puts the find bar top-right. Years of muscle memory. MIRA's bottom placement forces retraining. This is a 0-cost win — move it.

**4. The toolbar back/forward/reload buttons waste horizontal space**
On desktop, most users use keyboard shortcuts (Alt+Left, Ctrl+R) or mouse gestures. The icon buttons consume ~120px of toolbar width permanently. On a 1200px window this is 10% of the address bar's potential width gone.

**5. Menu popup is a 380px floating widget that looks like a mobile drawer**
`MiraMenuPage` with `desktopOverlay: true` is just the mobile menu rendered in a popup dialog. It has a full appbar with a close button, scrollable content, ListTiles — none of these are desktop-native patterns. A proper desktop menu should feel like a panel, not a floating phone screen.

**6. Ghost mode tab strip label is text-heavy and distracting**
"GHOST WORKSPACE" in bold red JetBrains Mono with a privacy icon takes up significant horizontal space. Arc handles private mode with a subtle color wash — the identity is communicated by atmosphere, not a label.

**7. No window drag area is communicated**
With `TitleBarStyle.hidden`, the entire window lacks a visual drag affordance. Users on Windows especially don't know where to grab the window. The tab strip is the drag zone but nothing indicates this.

**8. Address bar shows full raw URL**
`https://www.example.com/path/to/page?query=something` is shown verbatim. Research consistently shows that users don't read URLs — they look for the domain name. De-emphasizing the path and query reduces cognitive load and makes phishing domains more obvious.

**9. No tab previews on hover**
Hovering a tab chip shows nothing. On wide monitors with 10+ tabs in a sidebar, a thumbnail preview on hover is how users identify the right tab without clicking.

**10. Ctrl+Tab cycles tabs with no visual feedback**
Pressing Ctrl+Tab silently switches tabs. Chrome shows a small tab switcher overlay. Without feedback, users who accidentally trigger it don't know what happened.

---

## Redesign: The Sidebar Architecture

### North Star Layout

```
┌──────┬───────────────────────────────────────────────────────────┐
│      │  [←][→]  [🔒 example.com                      ★]  [🔍] │
│  S   ├───────────────────────────────────────────────────────────┤
│  I   │                                                           │
│  D   │                                                           │
│  E   │                   WEBVIEW CONTENT                         │
│  B   │                                                           │
│  A   │                                                           │
│  R   │                                                           │
│      │                                                           │
└──────┴───────────────────────────────────────────────────────────┘
```

### Sidebar — Expanded State (240px)

```
┌────────────────────────┐
│  M I R A          [⟨]  │  ← collapse button
├────────────────────────┤
│  [+] New Tab           │  ← primary action, always visible
├────────────────────────┤
│  ● [favicon] Tab Title │  ← active tab, accent dot
│    example.com         │    subdomain shown small
│                        │
│  ○ [favicon] YouTube   │
│    youtube.com         │
│                        │
│  ○ [favicon] GitHub    │
│    github.com       [×]│  ← close on hover only
│                        │
│  ○ [favicon] Reddit    │
│    reddit.com          │
├────────────────────────┤
│  ──── GHOST PROTOCOL ─ │  ← subtle separator, red tint section
│  ● [👁] Ghost Tab 1   │
│    (no URL saved)      │
├────────────────────────┤
│  ──────────────────    │
│  [⊞] Spaces    (v2)   │  ← future workspace switcher
│  [☆] Bookmarks        │
│  [⏱] History          │
│  [⬇] Downloads        │
├────────────────────────┤
│  [⚙] Settings         │  ← bottom, always accessible
└────────────────────────┘
```

### Sidebar — Collapsed State (52px icon rail)

```
┌────┐
│ M  │  ← MIRA icon / expand button
├────┤
│ +  │  ← new tab
├────┤
│ ●  │  ← active tab favicon (accent ring)
│    │
│ ○  │  ← favicon
│    │
│ ○  │
│    │
│ ○  │
├────┤
│ 👁 │  ← ghost section (red tint background)
├────┤
│ ☆  │
│ ⏱  │
│ ⬇  │
├────┤
│ ⚙  │
└────┘
```

### Tab Chip on Hover (sidebar expanded)

```
┌────────────────────────────────┐
│  ○ [favicon] GitHub         [×]│
│    github.com                  │
│  ┌──────────────────────────┐  │  ← thumbnail preview
│  │    [page screenshot]     │  │     appears 400ms after hover
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

---

## Toolbar Redesign

### Current (wasteful)
```
[←][→][↺]  [🔒 https://www.example.com/path?q=long        ★]  [⋮]
```

### Proposed
```
[←][→]  [🔒 example.com                                    ★][🔍][⋮]
```

Changes:
- **Remove reload button** — Ctrl+R / F5 covers this. Space reclaimed.
- **Domain-only display** — show `example.com` in full weight, grey out `https://` prefix and `/path` suffix. Clicking expands to full URL for editing.
- **Find button in toolbar** — `[🔍]` replaces the bottom find bar trigger. Opens a top-right overlay (Chrome-style), not a bottom sheet.
- **Keyboard shortcut overlay** — `Ctrl+?` opens a cheatsheet panel listing all shortcuts. Discoverability fix.

### Address Bar — Focused State
```
[🔒] https://www.example.com/path/to/page?query=something    [×]
      ↑ full URL revealed and selectable on focus
```

### Address Bar — Unfocused State
```
[🔒] example.com                                              [★]
      ↑ domain only, path greyed/hidden
```

---

## Find Bar — Move to Top Right

### Current (bottom overlay — wrong)
```
│                    WEBVIEW                    │
│                                               │
├───────────────────────────────────────────────┤
│ 🔍 [find in page...]   [↑][↓]           [×]  │  ← bottom
```

### Proposed (top right — industry standard)
```
│                              ┌────────────────┐
│                              │🔍 [find...]  × │  ← floats top-right
│                              │ 3 of 12   [↑][↓]│
│                              └────────────────┘
│           WEBVIEW                              │
```

---

## Ghost Mode — Atmosphere Not Label

### Current (text-heavy label)
```
│ 🔒 GHOST WORKSPACE │ [Tab 1 ×] [+] │
```

### Proposed (atmosphere-based)
```
┌──────────────────────────────────────────────┐
│  SIDEBAR TURNS                               │
│  DARK WITH RED                               │  ← entire sidebar shifts to
│  ACCENT. NO LABEL.                           │    near-black with red accent dots
│  THE FEEL IS PRIVATE.                        │    on ghost tab items only
└──────────────────────────────────────────────┘
```

Ghost tabs in the sidebar:
```
  ● [👁] research.com          ← red accent dot, ghost icon
  ○ [👁] another.com           ← no favicon (privacy), just ghost icon
```

No "GHOST WORKSPACE" label. The color shift communicates it.

---

## Micro-Interactions

| Trigger | Current | Proposed |
|---|---|---|
| New tab | Appears at end of strip | Slides in from right of sidebar with scale-up animation (120ms) |
| Close tab | Immediately removed | Chips above shift down with 80ms ease-out |
| Tab hover | Nothing | Favicon brightens, close [×] fades in, thumbnail appears after 400ms |
| Ctrl+Tab | Silent switch | Tab switcher overlay (like macOS Exposé) — 300ms blur background, tabs in a grid, release to select |
| Ghost mode activate | Instant color change | 200ms fade transition: sidebar darkens, accent shifts red, a subtle pulse on privacy icon |
| Sidebar collapse | Not implemented | 150ms ease-in-out slide, favicon rail slides in from left simultaneously |
| Find bar open | Bottom overlay appears | Top-right panel slides down from toolbar (80ms) |
| Window drag | No visual affordance | 2px drag handle visible at top of sidebar on hover |

---

## Spaces / Workspaces (V2 Feature)
_Noted for future — architecture should accommodate it now_

The sidebar bottom section reserves a `[⊞] Spaces` entry. A "Space" is a named collection of tabs with its own theme accent. Work Space (blue), Research Space (green), Ghost Space (red-always). Switching spaces replaces the tab list in the sidebar with an animated crossfade.

```
┌────────────────────────┐
│  [●] Work    ──────── │  ← active space
│  [○] Research          │
│  [👁] Ghost            │
│  [+] New Space         │
└────────────────────────┘
```

---

## Priority Implementation Order

| Priority | Change | Effort | Impact |
|---|---|---|---|
| 1 | Vertical sidebar (expanded + collapsed states) | High | Critical |
| 2 | Favicons in tab chips | Medium | High |
| 3 | Domain-only address bar display | Low | High |
| 4 | Move find bar to top-right | Low | Medium |
| 5 | Remove reload button from toolbar | Low | Low |
| 6 | Tab thumbnail on hover | Medium | Medium |
| 7 | Ghost mode atmosphere (no label) | Low | Medium |
| 8 | Ctrl+Tab switcher overlay | Medium | Medium |
| 9 | Window drag affordance | Low | Low |
| 10 | Spaces/Workspaces | High | V2 |
