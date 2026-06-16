# MIRA Firebase Speed Dial — Strategy
_CEO + Architect Mode | 2026-06-16_

---

## What This Is

Three capabilities sharing Firebase as infrastructure:

1. **Remote Speed Dial** — Firebase Remote Config serves the speed dial grid. Push changes from a web dashboard, users get them on next app open. No app update needed.

2. **Promotional Tiles** — A paid slot in the speed dial reserved for a partner (same model as Brave's sponsored new tab tiles). Clearly labeled. User-dismissible. Charged per impression or per tap.

3. **Analytics** — Firebase Analytics tracks tap events (organic vs promoted), impressions, conversion. This is what you sell to partners — verifiable impression and click counts.

---

## The Privacy Tension

Firebase Analytics sends data to Google. For a privacy-first browser, this is a contradiction that needs a clear position:

| Approach | Meaning | Trade-off |
|---|---|---|
| **Opt-in analytics** | User consents on first run, disabled by default | Clean privacy story, smaller data set |
| **Aggregated only** | No user-level events, aggregate counts only | Can't do per-partner conversion tracking |
| **Self-hosted** | Replace Firebase Analytics with Plausible/PostHog | Full control, no Google, higher ops cost |

**Recommended position:** Opt-in during onboarding. Copy: *"Help us keep MIRA free by sharing anonymous usage stats."* Analytics disabled by default, Remote Config always active (no PII in config fetches).

---

## Monetization Model

Same proven model as Brave new tab sponsored tiles:

- **Default grid:** 6 organic tiles curated by MIRA (YouTube, Reddit, GitHub, etc.)
- **Promoted slot:** 1–2 paid tiles per grid, clearly marked "Featured"
- **Billing:** Per-impression (shown) + per-tap (clicked) tracked via Firebase Analytics
- **User control:** Promoted tile has a dismiss button, preference stored in SharedPreferences

Revenue path: approach privacy-friendly search engines (DuckDuckGo, Brave Search, Kagi) and tools (Bitwarden, ProtonMail, Mullvad) as first partners. These brands align with MIRA's audience and won't undermine the privacy narrative.

---

## Firebase Remote Config Schema

Key name: `speed_dial_v1` (versioned to allow schema migration without breaking old installs)

```json
[
  {
    "id": "youtube",
    "label": "YouTube",
    "url": "https://m.youtube.com",
    "icon": "play_circle",
    "type": "organic"
  },
  {
    "id": "promo_duckduckgo",
    "label": "DuckDuckGo",
    "url": "https://duckduckgo.com",
    "icon": "https://duckduckgo.com/favicon.ico",
    "type": "promoted",
    "badge": "Featured"
  }
]
```

`type: organic` — curated default, not tracked for billing.  
`type: promoted` — paid slot, fires analytics events for impression + tap.  
`badge` — displayed text on tile (e.g. "Featured", "Sponsored", "New").  
`icon` — either a named icon string (mapped on client) or a favicon URL.

---

## Architecture (Fits MIRA's Clean Layers)

```
core/
  entities/speed_dial_item.dart          SpeedDialItem model
  services/speed_dial_repository.dart    Abstract interface
  notifiers/speed_dial_notifier.dart     StateNotifier — fetches, caches, exposes list

shell/
  firebase/
    firebase_speed_dial_repository.dart  Remote Config impl
    local_speed_dial_repository.dart     Hardcoded fallback (current 6 tiles)

pages/
  branding_screen.dart                   Reads speedDialProvider, renders grid
```

Current `_NormalSpeedDial` in `branding_screen.dart` becomes the local fallback while Remote Config loads. Provider pattern: show cached/local immediately, replace with remote on fetch.

---

## Firebase Packages Required

```yaml
firebase_core: ^3.x
firebase_remote_config: ^5.x
firebase_analytics: ^11.x   # opt-in only, conditionally initialized
```

---

## Open Questions (Resolve Before Building)

1. **Analytics opt-in or always-on?** Determines onboarding flow and privacy policy copy.
2. **How many promoted slots?** 1–2 max. More than 2 on a mobile grid feels like spam.
3. **Dismissible promoted tiles?** If yes — stored in SharedPreferences locally.
4. **Icon strategy?** Favicon URL from the site (flexible, no client-side map needed) vs string-to-icon map (works offline). Favicon preferred.
5. **Fetch timing?** On app cold start only, or also when branding screen is shown. Cold start preferred to avoid visible flash of content change.
6. **Cache TTL?** Remote Config minimum fetch interval. Recommend 12h in production, 0 in debug.

---

## Why This Works Strategically

- Brave's sponsored new tab tiles generate significant revenue without compromising user trust (tiles are labeled, dismissible, partner-curated).
- MIRA's audience (privacy-conscious Android users) is exactly the high-intent demographic that DuckDuckGo, Bitwarden, Mullvad, and ProtonMail actively pay to reach.
- Remote Config gives the team a lever to iterate speed dial content, run A/B tests, and push seasonal promotions without waiting for Play Store review cycles.
- Firebase Remote Config fetches are not user-identifying — only analytics (if opted in) introduces any PII risk.
