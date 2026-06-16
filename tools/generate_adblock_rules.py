#!/usr/bin/env python3
"""
Generate assets/adblock/content_blockers.json from DDG Tracker Data Standard.

Usage:
  python tools/generate_adblock_rules.py              # fetch from CDN
  python tools/generate_adblock_rules.py --local tds.json  # use local file
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

TDS_URL = (
    "https://raw.githubusercontent.com/duckduckgo/tracker-blocklists"
    "/main/web/v6/extension-tds.json"
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

        # BLOCK rule FIRST (lower index).
        # IGNORE_PREVIOUS_RULES (below) can only cancel rules at lower indices.
        rules.append({
            "trigger": {
                "urlFilter": escaped,
                "loadType": ["THIRD_PARTY"],
            },
            "action": {"type": "BLOCK"},
        })

        # Exception rules AFTER (higher index).
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
    print(f"Generated {len(rules)} rules covering {blocked} domains -> {OUT_PATH}")


if __name__ == "__main__":
    main()
