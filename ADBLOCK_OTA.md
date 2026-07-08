# AdBlock OTA — Weekly Tracker-List Refresh

Keeps MIRA's tracker blocklist current **without shipping an app update**. A
GitHub Action recompiles DuckDuckGo's curated blocklist once a week and
publishes it to GitHub Releases; the app pulls it on a 7-day cadence and applies
it on the next launch. The blocklist bundled in the app is always the offline
fallback, so nothing breaks if the network or the release is unavailable.

---

## How it works

```
DuckDuckGo extension-tds.json
        │  (weekly cron, GitHub Actions)
        ▼
generate_adblock_rules.py ──► content_blockers.json  (WebKit ContentBlocker rules)
        │                     manifest.json           ({schemaVersion, generatedAt, sha256, ruleCount})
        ▼
validate_blocklist.py        (gate: rejects malformed / over- or under-blocking output)
        ▼
GitHub Release  (tag blocklist-YYYY-MM-DD, assets attached)
        │
        ▼  https://github.com/<owner>/<repo>/releases/latest/download/{manifest,content_blockers}.json
        │
        ▼  (app launch, throttled to once / 7 days)
AdBlockOtaService.maybeRefresh()
   GET manifest → sha changed? → GET rules → verify sha256 → atomic write to app-support dir
        ▼
AdBlockService.loadRules()   (NEXT launch: loads OTA file if present, else bundled asset)
```

**Key design choices**
- **Apply on next launch**, not live. Downloads land on disk; the running
  webviews are never mutated mid-session.
- **Integrity-checked.** The downloaded bytes must match the `sha256` in the
  manifest or the update is discarded.
- **Fail-safe.** Any network/parse/verify error is a no-op — the last good list
  (or the bundled asset) keeps working.
- **Platform note.** WebKit ContentBlockers only run on **Android / iOS /
  macOS**. On Windows/Linux the rules are skipped entirely (plugin limitation),
  so the OTA file is downloaded but unused there.

---

## Files

| File | Role |
|------|------|
| `tools/generate_adblock_rules.py` | Fetches DDG list, emits `content_blockers.json` + `manifest.json`. **Selection logic unchanged** from the original generator. |
| `tools/validate_blocklist.py` | CI gate. Compares candidate vs the committed golden asset (≥50% rule count, ≥70% BLOCK-domain overlap). |
| `.github/workflows/update-blocklist.yml` | Weekly cron (Mon 06:00 UTC) + manual dispatch → generate → validate → publish Release. |
| `lib/core/services/adblock_ota_service.dart` | Client fetch/verify/write. Repo URL lives in **one** constant (`_releaseBase`). |
| `lib/core/services/adblock_service.dart` | Loads OTA disk file first, falls back to bundled asset. |
| `lib/core/services/preferences_service.dart` | Stores last-check timestamp + last-applied sha. |
| `lib/main.dart` | Fires `maybeRefresh()` after `runApp` (non-blocking). |
| `assets/adblock/content_blockers.json` | Bundled fallback list (shipped in the app). |

---

## ✅ What remains on your part (manual steps)

These are **not done** and require your action:

1. **Push the branch / open a PR.**
   ```
   git push -u origin feat/adblock-ota
   ```
   Nothing is on `master` yet — the feature lives only on `feat/adblock-ota`.

2. **Run the workflow once to create the first Release.**
   Until a Release exists, the `releases/latest/download/...` URLs return 404 and
   the app simply uses the bundled asset (no harm, just no OTA yet).
   - GitHub → **Actions** → **Update blocklist** → **Run workflow**, or
     `gh workflow run update-blocklist.yml`.
   - Confirm a release tagged `blocklist-YYYY-MM-DD` appears with **both**
     `content_blockers.json` and `manifest.json` attached.
   - Verify the stable URL works (open in a browser):
     `https://github.com/<owner>/<repo>/releases/latest/download/manifest.json`

3. **Test the client round-trip on a real device** (Android/iOS/macOS).
   This can only be tested *after* step 2, since it needs a live Release.
   First launch loads the bundled asset; the background fetch downloads the OTA
   file; the **second** launch should load the fresher list from disk.

4. **Keep the bundled asset reasonably fresh (optional, occasional).**
   The bundled `content_blockers.json` is what brand-new installs use before
   their first OTA fetch. Regenerate it now and then so fresh installs aren't
   starting from a stale list:
   ```
   python tools/generate_adblock_rules.py   # overwrites assets/adblock/content_blockers.json
   git add assets/adblock/content_blockers.json && git commit
   ```
   (The `manifest.json` it also writes is gitignored — it's a CI/release artifact.)

5. **If you rebrand / move the repo:** change the one line in
   `adblock_ota_service.dart`:
   ```dart
   static const _releaseBase =
       'https://github.com/<new-owner>/<new-repo>/releases/latest/download';
   ```
   The CI workflow needs **no** change — it publishes to whatever repo it runs in.

---

## Unrelated pending items (not part of this feature)

- `lib/pages/onboarding_screen.dart` has an uncommitted fix from earlier — commit
  it separately when ready.
