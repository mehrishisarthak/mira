#!/usr/bin/env python3
"""
Validate the freshly generated content_blockers.json against the committed
golden reference (read from git HEAD), so the gate works on the first run.

Exits non-zero on any failure.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

RULES_PATH = Path("assets/adblock/content_blockers.json")
GOLDEN_REF = f"HEAD:{RULES_PATH.as_posix()}"

MIN_RULE_RATIO = 0.50      # new ruleCount must be >= 50% of golden
MIN_DOMAIN_OVERLAP = 0.70  # BLOCK-domain overlap with golden must be >= 70%

# Mirror of escape_domain() in generate_adblock_rules.py:
#   (^|\.)<re.escape(domain)>(/|$|[/?#])
URL_FILTER_RE = re.compile(r"^\(\^\|\\\.\)(.*)\(/\|\$\|\[/\?#\]\)$")


def block_domains(rules: list[dict]) -> set[str]:
    domains = set()
    for rule in rules:
        if rule.get("action", {}).get("type") != "BLOCK":
            continue
        url_filter = rule.get("trigger", {}).get("urlFilter", "")
        m = URL_FILTER_RE.match(url_filter)
        if not m:
            continue
        # Undo re.escape: drop backslashes that escape regex metacharacters.
        domains.add(re.sub(r"\\(.)", r"\1", m.group(1)))
    return domains


def main() -> int:
    candidate_bytes = RULES_PATH.read_bytes()
    try:
        candidate = json.loads(candidate_bytes)
    except json.JSONDecodeError as e:
        print(f"FAIL: candidate rules JSON is malformed: {e}")
        return 1
    if not isinstance(candidate, list):
        print("FAIL: candidate rules JSON is not a list")
        return 1

    golden_bytes = subprocess.run(
        ["git", "show", GOLDEN_REF],
        check=True, capture_output=True,
    ).stdout
    golden = json.loads(golden_bytes)

    golden_count = len(golden)
    candidate_count = len(candidate)
    if candidate_count < MIN_RULE_RATIO * golden_count:
        print(
            f"FAIL: ruleCount {candidate_count} < "
            f"{MIN_RULE_RATIO:.0%} of golden {golden_count}"
        )
        return 1

    golden_domains = block_domains(golden)
    candidate_domains = block_domains(candidate)
    if not golden_domains:
        print("FAIL: extracted zero BLOCK domains from golden (extraction bug)")
        return 1
    overlap = len(golden_domains & candidate_domains) / len(golden_domains)
    if overlap < MIN_DOMAIN_OVERLAP:
        print(
            f"FAIL: BLOCK-domain overlap {overlap:.1%} < "
            f"{MIN_DOMAIN_OVERLAP:.0%}"
        )
        return 1

    print(
        f"OK: ruleCount {candidate_count} (golden {golden_count}), "
        f"BLOCK-domain overlap {overlap:.1%}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
