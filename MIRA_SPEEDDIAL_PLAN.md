# MIRA Speed Dial — Dynamic Homescreen Plan (Firebase-free)

_Architect + Validator Mode | 2026-06-19_

> **Supersedes [`MIRA_FIREBASE_SPEEDDIAL_STRATEGY.md`](./MIRA_FIREBASE_SPEEDDIAL_STRATEGY.md).**
> That doc relied on Firebase Remote Config + Analytics. This plan removes Firebase entirely by
> reusing the OTA mechanism already shipped for the ad blocklist (see [`ADBLOCK_OTA.md`](./ADBLOCK_OTA.md)).

---

## The reframe

A Brave-style **dynamic, monetizable homescreen** (push tiles without an app update, plus a sponsored
slot) needs three things. The Firebase doc used Firebase for all three. We no longer need it for any:

| Capability | Firebase doc | This plan |
|---|---|---|
| Push config without app update | Remote Config | **Reuse the OTA pattern** — a GitHub Release-delivered `speeddial.json`, fetched/verified client-side |
| Sponsored tiles | data in Remote Config | data in `speeddial.json` — no infra |
| Billing analytics | Firebase Analytics → Google | **No client analytics at all** (see §4) |

Removing Firebase drops 3 heavyweight deps (`firebase_core` / `_remote_config` / `_analytics`), the
AOT/init complexity, **and** the core privacy contradiction. Strictly better on every axis.

---

## 1. Delivery — mirror the blocklist OTA

A new `SpeedDialOtaService`, near-identical to the shipped `AdBlockOtaService`:

- Throttled fetch (**12–24h** — shorter than the blocklist's 7d, since promos rotate faster).
- `GET speeddial.json` + `speeddial_manifest.json` → **sha256-verify** → atomic write to app-support →
  apply on next home render.
- **Bundled fallback:** `assets/speeddial/speeddial.json` ships the current 6 organic tiles.
  Offline / first-run / parse-failure → bundled defaults (mirror `AdBlockService._tryLoadFromDisk`,
  which returns null on any read/parse error and falls back to the asset).

No Firebase, no Google SDK, no per-user fetch identity. The fetch is an anonymous `GET`, exactly like
the blocklist.

## 2. Architecture (fits the clean layers; mirrors the blocklist 1:1)

```
core/
  entities/speed_dial_item.dart        // id, label, url, icon, type, badge
  services/speed_dial_service.dart     // disk-first load, bundled fallback (≈ AdBlockService)
  services/speed_dial_ota_service.dart // fetch / verify / write   (≈ AdBlockOtaService)
  providers/speed_dial_provider.dart   // exposes List<SpeedDialItem>
pages/
  branding_screen.dart                 // _NormalSpeedDial reads the provider; today's hardcoded
                                        //   `const items` list becomes the bundled default
assets/speeddial/speeddial.json        // shipped defaults
```

## 3. Schema (kept from the Firebase doc — it's good)

```json
{
  "schemaVersion": 1,
  "tiles": [
    { "id": "youtube", "label": "YouTube", "url": "https://m.youtube.com", "icon": "play_circle", "type": "organic" },
    { "id": "promo_proton", "label": "Proton Mail", "url": "https://proton.me", "icon": "proton", "type": "promoted", "badge": "Featured" }
  ]
}
```

- `type: organic` — curated default, never billed.
- `type: promoted` — paid slot; renders a `badge` and a dismiss control.
- `icon` — **named-icon string only** (mapped client-side). Not a favicon URL — see Validator finding #1.

## 4. Monetization without tracking (the key redesign)

Brave uses CPM/CPC, which *requires* tracking. MIRA doesn't have to — and *not* tracking is a stronger
pitch than Brave's:

- **Start with flat-fee sponsorship.** Sell the "Featured" slot for a fixed monthly fee. Zero analytics,
  zero infra, zero privacy cost.
- **Attribution lives with the partner**, via their own campaign links — *they* see the clicks on their
  dashboard; MIRA measures nothing. Narrative: **"We don't even count. Your numbers are yours."** A
  privacy flex no tracking-based competitor can make.
- Add privacy-preserving *aggregate* counts only later, only if a partner demands verifiable numbers and
  accepts anonymous aggregates (self-hosted, Plausible-style, never per-user). **Deferred for v1.**

---

## Validator audit

**Verdict: architecture is sound and correctly reuses proven infra. Six findings — two blocking.**

### 🔴 Blocking

1. **Favicon hot-linking re-introduces tracking by the back door.** If a promoted tile loads its icon
   from `proton.me/favicon.ico`, then *rendering the homescreen pings the partner's server* — exactly
   the tracking we're avoiding. **Fix: never hot-link remote icons. Use named-icon strings (or bundle
   the icon in the payload). The homescreen must make zero third-party requests at render.**

2. **The `releases/latest/download/` channel collides with the blocklist.** GitHub's `latest` points to
   the newest release of *any* kind; a speed-dial release becoming "latest" would 404 the blocklist's
   `latest/download/content_blockers.json`. **Fix: do not use `latest` for speed dial. Publish to a
   fixed, updated-in-place tag** (e.g. `config`) and fetch `releases/download/config/speeddial.json`.

### 🟡 Should-fix

3. **Higher supply-chain stakes than the blocklist** — you're pushing *clickable "Featured" URLs*. A
   compromised release could surface phishing; sha256 protects transit, not a bad source. **Add a
   client-side allowlist of permitted promoted domains**; ignore promoted tiles outside it.

4. **Defensive / forward-compatible parsing.** Old installs must ignore unknown `type`/fields and fall
   back to bundled defaults on any parse error (same discipline as the blocklist). Enforce
   `schemaVersion` + null-on-error.

### 🟢 Note / defer

5. **DRY vs. don't-touch-shipped-code.** `SpeedDialOtaService` will be ~90% identical to
   `AdBlockOtaService`. **Do not** extract a shared `OtaConfigFetcher` yet — the blocklist OTA is
   shipped, tested, and in production; refactoring it to serve a second consumer risks destabilizing
   live code for a DRY win. Build speed dial standalone (copy the pattern); extract a shared fetcher only
   if a *third* consumer appears. Honors "surgical changes / don't refactor what isn't broken."

6. **Apply-on-next-render, not live-swap**, to avoid a visible content flash mid-session (consistent with
   the blocklist's apply-on-next-launch).

---

## Consolidated plan (build order)

1. **Drop Firebase entirely.** Deliver via the OTA pattern; monetize flat-fee with partner-side attribution.
2. **P1 — data-driven grid (low risk, ship first):** refactor `_NormalSpeedDial` to read
   `speedDialProvider` from a bundled `assets/speeddial/speeddial.json`. **No remote yet.**
3. **P2 — dynamic delivery:** add `SpeedDialOtaService` on a **fixed `config` tag** (not `latest`), with
   **named/bundled icons only** (no favicon hot-linking) and a **promoted-domain allowlist**.
4. **P3 — sponsored tiles:** badge + dismiss (dismissal stored in prefs by id) + first flat-fee partner
   (Proton / Mullvad / DuckDuckGo — MIRA's audience is exactly their buyer).
5. **Defer** all analytics; keep the two OTA services separate for now.

**Net:** a Brave-style dynamic, monetizable homescreen that makes **zero third-party requests at render
and tracks nothing** — a cleaner privacy story than Brave, built on infrastructure already shipped.
