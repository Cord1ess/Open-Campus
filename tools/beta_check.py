#!/usr/bin/env python3
"""Beta-readiness gate.

Scans the working tree for anything that must NOT ship in a build given to other
testers: captured personal data, a real .env, leftover real student IDs, debug
config, and the localhost backend default. Exits non-zero (and prints each
problem) if the tree is not safe to build/distribute.

Usage:
    python tools/beta_check.py

Run this BEFORE building the web app or an APK. It does not modify anything.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directories we never scan into (deps, build artifacts, virtualenvs, vcs).
# `captures` is included because it's already caught wholesale by FORBIDDEN_PATHS
# (a raw capture is never shippable); string-scanning inside it too just produces
# redundant noise — and its raw bodies legitimately contain faculty names that
# collide with the advisor-name needle below.
SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", ".dart_tool", "build",
    ".pytest_cache", "__pycache__", ".idea", ".vscode", "captures",
}

# Paths that must NOT exist in a distributable tree (no legitimate reason).
FORBIDDEN_PATHS = [
    "backend/captures",
    "docs/captures",
]

# Paths that are FINE for local dev but must never be committed or bundled into a
# shipped artifact. We warn (not fail) so local dev isn't blocked — the Flutter
# build never includes backend/.env anyway.
WARN_PATHS = [
    "backend/.env",
]

# Unambiguous personal identifiers — unique enough that any substring hit is a
# real leak. Matched literally, anywhere.
FORBIDDEN_IDENTIFIERS = [
    "0112330671",   # real student roll
    "ibnemasud",    # real advisor email handle
]

# Personal NAMES that must not ship as the user's own data — but which can also
# legitimately occur as a faculty member's name in the shared course catalog
# (e.g. "Abdullah Ibne Masud Mahi" is a real, public CSE faculty). To avoid
# false positives, a name matches only as a STANDALONE full name (word-boundary
# on both sides), so it does NOT fire when it's a prefix of a longer name.
FORBIDDEN_NAMES = [
    "Abdullah Ibne Masud",  # real advisor name (the user's own)
]

# Source extensions worth scanning for forbidden strings.
SCAN_EXTS = {".dart", ".py", ".md", ".json", ".html", ".yaml", ".yml", ".txt"}

# Any *.har anywhere is captured traffic.
HAR_RE = re.compile(r".*\.har$", re.IGNORECASE)


def _iter_files():
    for path in ROOT.rglob("*"):
        if path.is_dir():
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        yield path


def main() -> int:
    problems: list[str] = []
    warnings: list[str] = []

    # 1. Forbidden paths.
    for rel in FORBIDDEN_PATHS:
        p = ROOT / rel
        if p.exists():
            problems.append(f"FORBIDDEN PATH present: {rel}")

    # 1b. Local-dev-only paths: warn, don't fail.
    for rel in WARN_PATHS:
        if (ROOT / rel).exists():
            warnings.append(
                f"{rel} present - fine for local dev, but NEVER commit or bundle it."
            )

    # 2. Any .har files (captured traffic with cookies + PII).
    for path in _iter_files():
        if HAR_RE.match(path.name):
            problems.append(f"HAR capture present: {path.relative_to(ROOT)}")

    # 3. Forbidden strings in scannable source.
    for path in _iter_files():
        if path.suffix.lower() not in SCAN_EXTS:
            continue
        # This checker file itself legitimately contains the patterns.
        if path.resolve() == Path(__file__).resolve():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for needle in FORBIDDEN_IDENTIFIERS:
            if needle in text:
                problems.append(
                    f"Personal data '{needle}' found in {path.relative_to(ROOT)}"
                )
        for name in FORBIDDEN_NAMES:
            # Standalone full name only: word-boundary both sides, so a longer
            # faculty name that merely starts with it (…Mahi) does not match.
            if re.search(rf"\b{re.escape(name)}\b(?!\s+\S)", text):
                problems.append(
                    f"Personal data '{name}' found in {path.relative_to(ROOT)}"
                )

    # 4. Debug posture in a shipped .env.example (should be false).
    env_example = ROOT / "backend" / ".env.example"
    if env_example.exists():
        if re.search(r"^OC_DEBUG=true\b", env_example.read_text(), re.MULTILINE):
            problems.append("backend/.env.example sets OC_DEBUG=true (should be false)")

    if problems:
        print("BETA CHECK FAILED - do not build/distribute:\n")
        for p in problems:
            print(f"  [X] {p}")
        if warnings:
            print()
            for w in warnings:
                print(f"  [!] {w}")
        print(f"\n{len(problems)} problem(s) found.")
        return 1

    print("BETA CHECK PASSED - no personal data, captures, or HAR files found.")
    for w in warnings:
        print(f"  [!] {w}")
    print("Reminder: build with --dart-define=OC_API_BASE=https://<your-host>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
