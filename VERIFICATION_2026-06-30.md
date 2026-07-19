# Qyx — Verification & Profiling Guide (2026-06-30 changes)

Covers the 10 commits from the performance pass: **O-50, O-51, O-49 (+hardening),
O-11, O-18, O-04**. Two parts:

- **Part A — Functional checks** (does each change work / nothing broke). Phone or emulator.
- **Part B — Profiling** (does the perf win actually land). **Physical Android device required.**

> ⚠️ **Profile/release only for perf.** Debug builds (`flutter run`) show fake jank from
> Hybrid Composition. Judge *all* performance on `--profile` (or release) on a **real device**.
> Functional checks (Part A) are fine on any build.

---

## 0. Prerequisites

```bash
# Device connected, USB debugging on:
adb devices

# App package id:
#   com.classified.mira

# Device RAM (needed for O-47 later — record this number):
adb shell cat /proc/meminfo | grep MemTotal

# Display refresh rate (sets the frame budget: 60Hz=16.7ms, 120Hz=8.3ms):
adb shell dumpsys display | grep -i "mRefreshRate\|fps"
```

Builds you'll use:
- **Functional (Part A):** `flutter run` (debug is fine) **except** the O-04 plaintext check, which needs a **debug** build for `run-as`.
- **Profiling (Part B):** `flutter run --profile`.

---

## Part A — Functional verification

Do **A1 first** (data safety). For each: ✅ = pass, ❌ = what failure looks like.

### A1 — O-04 Encrypted tab storage  *(most important — precious data)*

**Basic persistence**
1. Open 3–4 tabs, each on a **distinct** real URL (e.g. wikipedia.org, github.com, a news site). Let them load.
2. Fully close the app (swipe from recents).
3. Reopen.
- ✅ All tabs restored with the right URLs and the right active tab.
- ❌ Tabs missing / reset to one blank tab → secure load failed and fallback didn't catch it.

**Privacy proof — plaintext is gone** *(needs a `flutter run` debug build)*
```bash
# List prefs files:
adb shell run-as com.classified.mira ls -la shared_prefs

# Confirm one of YOUR tab URLs is NOT sitting in plaintext:
adb shell run-as com.classified.mira cat shared_prefs/FlutterSharedPreferences.xml | grep -i "wikipedia\|github"
```
- ✅ The `grep` returns **nothing** (URLs are not in the plaintext XML), and you can see a
  `FlutterSecureStorage.xml` (or `*.encrypted`) file holding opaque blobs.
- ❌ Your tab URLs appear in `FlutterSharedPreferences.xml` → still plaintext.

**Migration (only if you have pre-O-04 data)**
- If you had tabs saved on an **older** build, install this build over it (don't wipe data),
  open the app once, then run the plaintext grep above.
- ✅ Tabs restored **and** the plaintext copy is wiped (grep empty).

### A2 — O-49 Tab-sheet snapshot-swap  *(the perceived-perf win)*

**Smoothness**
1. Load a **heavy** page (YouTube, a media-rich homepage). Let it fully render.
2. Tap the **tab counter** (bottom bar) to open the tab sheet.
- ✅ Sheet slides up smoothly; the page behind it looks **frozen** (it's a screenshot) — no stutter.
- ❌ Visible hitch/stutter as the sheet animates → snapshot-swap not taking effect.

**Tab-switch from the sheet (the tab-scoping fix)**
3. With the sheet open, tap a **different** tab.
- ✅ The new tab appears **live** as the sheet closes.
- ❌ You briefly see the **previous** page's screenshot over the new tab during the close → tab-scoping broke.

**Video pause (the hibernate/wake fix)**
4. Play a video (with sound). Open the tab sheet.
- ✅ Audio/video **pauses** while the sheet is open; **resumes** on close.
- ❌ Video keeps playing behind the sheet.

**Start-page fallback (null capture)**
5. On a **blank/start** tab (no page loaded), tap the tab counter.
- ✅ Sheet opens normally, no crash.

### A3 — O-50 Opaque webview surface  *(no visual regression)*

1. Load several pages, **including a dark-themed site** and a **slow-loading** page.
- ✅ No white flash before paint (skeleton covers the load); dark pages don't flash white.
- ❌ A white frame appears before a dark page paints → tell me; fix is an opaque themed background instead.

*(The actual raster win is measured in Part B, not by eye.)*

### A4 — O-11 Flush tabs on background/kill

1. Open a tab and navigate to a new URL.
2. **Immediately** (don't wait) press **Home** to background the app.
3. Swipe the app away from recents (force-kill).
4. Reopen.
- ✅ The last navigated URL is restored.
- ❌ It reverted to the previous URL → the pre-kill flush didn't fire.

### A5 — O-18 Desktop download timeout  *(desktop only — optional)*

1. On Windows (`flutter run -d windows`), trigger a download from a URL that connects but
   stalls (a very slow endpoint, or pull the network mid-download).
- ✅ The download flips to **failed** after ~30–60 s instead of hanging forever.
- ❌ It spins indefinitely.

### A6 — O-51 Find-bar watch  *(desktop; not user-visible)*

This is a rebuild-count optimization with no visible behavior change — it's covered by
`flutter analyze` + the test suite. The only user-facing check: desktop find-in-page
(`Ctrl/Cmd+F`) still highlights and steps through matches correctly.

---

## Part B — Profiling protocol

**Goal:** confirm the O-49/O-50 wins, re-confirm the still-open O-42/O-43/O-47/O-48 with
fresh numbers, and finally capture the **device-RAM** figure O-47 needs.

### B0 — Setup
```bash
flutter run --profile        # on the physical device
```
- Open **DevTools** (URL printed in the console, or the IDE button) → **Performance** tab.
- Quickest live read: in the `flutter run` console press **`P`** to toggle the **performance
  overlay** — two graphs (top = UI/build thread, bottom = raster/GPU thread). Bars **under**
  the white line = within budget; **red spikes above** = jank.

### B1 — Capture & export each run
For each capture below:
1. In DevTools Performance, click **Clear**.
2. Perform the interaction (described per capture).
3. Click the **Export/Save** button → save into `profile test reports/` with the given name.
4. Also note from the **Frames** chart: total frames, # janky (red), UI p50/max, raster p50/max.

Analyze a saved file with the kept scripts:
```bash
cd "profile test reports"
python _frames.py <file>.json      # per-frame build/raster summary (DevTools frame export)
python _analyze.py <file>.json     # raw traceEvents breakdown (HC cost by thread)
```

### B2 — The captures to run

| # | Name (save as) | Setup | Action | Watch |
|---|----------------|-------|--------|-------|
| C1 | `tabsheet_static.json` | Load a **static heavy** page, fully rendered | Open the tab sheet, wait, close | **Raster p50** during the open. Target: well below the old **10–13 ms**; ~0 janky frames. **This validates O-49 + O-50.** |
| C2 | `tabsheet_video.json` | Load a **video** page, playing | Open the tab sheet, wait, close | Same as C1, plus confirm in logcat the page isn't still decoding (O-49 pause). |
| C3 | `switchback.json` | Open **>4** tabs on real pages (forces eviction past the cap) | Switch to one of the **oldest** evicted tabs | Build stalls on switch-back + whether the page **reloads**. Re-confirms **O-42** (expected: still stalls ~77–141 ms + reload — not yet fixed). |
| C4 | `coldstart.json` | Have several tabs saved, then **fully restart** the app | Let the first restored page mount | First-webview-mount build stalls. Re-confirms **O-48** (expected: ~129 + 90 ms — not yet fixed). |
| C5 | `keyboard_heavy.json` | Load a **heavy** page, confirm it's compositing (raster p50 ~10+ ms, not 4 ms) | **Focus the omnibox** so the keyboard opens | Raster spikes during the keyboard animation. **This is the O-43 re-run the doc demands** — if it spikes → O-43 confirmed; if smooth → O-43 can be rejected. |
| C6 | `meminfo.txt` (paste output) | Open **4** live webviews | — | Run the meminfo command below; record **TOTAL PSS** + **EGL/Graphics**. With the device-RAM number from §0, this finalizes **O-47** severity. |

```bash
# C6 memory snapshot (foreground, with 4 webviews live):
adb shell dumpsys meminfo com.classified.mira | grep -i "TOTAL\|EGL\|Graphics\|Gfx"
```

### B3 — How to read it (old baselines to beat / re-confirm)

| Metric | Old (2026-06-24) | After this pass |
|--------|------------------|-----------------|
| Raster p50, webview present | 10–13 ms | **Should drop** toward the ~4 ms webview-absent floor (O-50 opaque surface) |
| Tab-sheet open jank | user-felt lag (never profiled) | **~0 janky frames** (O-49 snapshot-swap) |
| Switch-back build stall (O-42) | 77–141 ms + reload | **Unchanged expected** (O-42 still open) |
| Cold-restore build stall (O-48) | 129 + 90 ms | **Unchanged expected** (O-48 still open) |
| Keyboard-resize (O-43) | not exercised | **Now tested** with a heavy page → confirm or reject |

**Save all exports into `profile test reports/`.** Send me the numbers (or the files) and I'll
update `ISSUES.md`: close/adjust O-49/O-50, finalize O-47 with the RAM figure, and confirm-or-reject O-43.

---

## Part C — A/B comparison (optional, to *feel* the wins)

To compare before/after for O-49 + O-50 on the same device:
```bash
git stash                       # if you have uncommitted work
git checkout 083d831~1          # commit just BEFORE this pass
flutter run --profile           # feel the old tab-sheet lag
git checkout master             # back to the fixes
flutter run --profile           # feel the difference
```
`083d831` is the first commit of this pass; `083d831~1` is the state before any of it.
