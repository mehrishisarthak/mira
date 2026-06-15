# MIRA AI Strategy
_CEO Mode — 2026-06-16_

---

## The Core Thesis

Every browser with AI today sends your page content to a cloud server. Chrome sends it to Google. Edge sends it to Microsoft. Brave Leo sends it to Brave's servers. The content leaves your device — always.

For a normal browser this is an acceptable tradeoff.

**For a privacy browser, this is a self-contradiction.** You built a product around not being surveilled, then added a feature that sends everything you read to a third party. Brave tries to paper over this with "anonymous requests" marketing but the architecture is the same.

That is the gap MIRA can own: **AI that never requires your content to leave the device.**

The pitch is not "we have AI too." It is "we are the only browser where the AI is as private as the browser itself."

---

## Phase 1 — Defensive AI (No LLM Required, Ship Now)

These require no language model. They run entirely via JavaScript injection and WebView's `shouldInterceptRequest`. Buildable in weeks.

### 1. Dark Pattern Detector
Intercept and flag:
- Forced login walls before content loads
- Cookie consent dark patterns (pre-checked boxes, hidden reject buttons)
- Countdown timers designed to pressure users
- Fingerprinting script signatures (canvas, AudioContext, WebGL probing)

Surface as a small shield badge in the address bar. Tap to see what was blocked.

**Why this matters:** No browser does this well on mobile. It aligns perfectly with the MIRA privacy narrative and requires zero server calls.

### 2. Reader Mode
- Inject Mozilla's Readability.js via `evaluateJavascript`
- Detect if page is an article, surface a clean reading icon in the address bar
- Strip nav, ads, sidebars, show clean text with MIRA's theme applied

**Why this matters:** Firefox has it. Safari has it. Chrome doesn't. Power users expect it. Pure JS injection — no model, no server.

### 3. Tracker Scorecard
- Every page load, audit all third-party requests intercepted via `shouldInterceptRequest`
- Build a local score: how many trackers, what categories (ad, analytics, social)
- Show a simple badge — clean / moderate / heavy tracker load

**Why this matters:** uBlock origin does this for desktop. No mobile browser does it cleanly. Keeps users inside MIRA instead of opening a separate privacy app.

---

## Phase 2 — On-Device AI (V2, Post-Alpha)

### The Architecture Requirement
Any AI feature in MIRA must satisfy one rule: **inference happens on device, content never leaves.**

Viable approaches for Flutter on Android:
- **Google Gemini Nano** — on-device via Android AICore API (Android 10+, Pixel 6+ and expanding). Free, Google-maintained, no model bundling needed.
- **MediaPipe LLM Inference** — Google's on-device LLM task API, supports Gemma 2B/7B. Flutter plugin exists (`google_mediapipe`).
- **llama.cpp via FFI** — bundle a quantized 1B–3B model (Llama 3.2, Phi-3 Mini, Gemma 2B). Most flexible, largest binary size (~800MB for 3B Q4).

Start with Gemini Nano (AICore) — zero bundle size, maintained by Google, expands to more devices each Android update.

### Feature 1 — Page Summarizer
- Extract page text via `document.body.innerText` through `evaluateJavascript`
- Pass to on-device model
- Return a 3–5 sentence summary shown in a bottom sheet
- Ghost mode compatible — no history, no server, nothing persists

**The pitch:** "Summarize any page. Nothing leaves your phone."

### Feature 2 — Ask This Page
- Same text extraction
- User types a question in a text field
- On-device model answers based only on the page content
- Think: ChatPDF but for any webpage, fully local

### Feature 3 — Ghost AI Mode
- In ghost/private mode, AI features are available but store absolutely nothing
- No conversation history, no page cache, inference result discarded on close
- This is the key differentiator — cloud AI cannot offer this. If the content never reaches a server, there is nothing to log.

### Feature 4 — Privacy Assistant (Stretch)
- Proactive, not reactive
- "This site is requesting your location, microphone, and camera simultaneously. That's unusual for a news site."
- "You've visited 6 different health websites this session. Switch to Ghost mode?"
- Runs a lightweight classifier on page metadata + request patterns, no LLM needed for this one

---

## What Makes This Different From Brave Leo / Edge Copilot

| | Brave Leo | Edge Copilot | MIRA AI |
|---|---|---|---|
| Inference location | Brave servers | Microsoft servers | On device |
| Content leaves device | Yes | Yes | No |
| Works in private mode | No | No | Yes |
| Works offline | No | No | Yes |
| Verifiably private | No (trust us) | No (trust us) | Yes (auditable) |
| Model choice | Fixed (Llama) | Fixed (GPT-4) | Swappable |

The "verifiably private" row is the strategic moat. Open-source the on-device inference pipeline. Let users and security researchers audit that no network call is made during AI use. That is a claim no cloud-based browser AI can ever make.

---

## When to Build This

**Do not build AI for the Android alpha.** The foundation is not ready:
- Downloads are broken
- History URLs are broken
- Update screen crashes on skip
- Web errors show a blank page

Ship the alpha clean. Get real users. Let usage data tell you which features they actually want. AI for a 50-user alpha is noise.

**Trigger for Phase 1 (Defensive AI):** When the core browser is stable and the Play Store rating is above 4.0.

**Trigger for Phase 2 (On-Device LLM):** When MIRA has a meaningful Android user base (~5k+ MAU) and Gemini Nano device coverage is broad enough to make the feature non-niche.

---

## The One-Line Pitch When It Ships

> "Every other browser's AI reads your pages. MIRA's AI never leaves your phone."
