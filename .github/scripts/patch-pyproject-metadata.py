#!/usr/bin/env python3
"""Patch pyproject.toml metadata for vllm-cpu package.

Updates authors, maintainers, and project URLs.
Does NOT touch license fields (upstream Apache-2.0 + PEP 639 format works as-is).
Keeps Homepage pointing to upstream vllm-project/vllm.
"""
import re
import pathlib
import sys


def rewrite_direct_url_requirements(text: str) -> tuple[str, int]:
    """Rewrite direct URL requirements into plain package requirements."""
    rewritten = 0
    lines = []

    quoted_req = re.compile(
        r'^(?P<prefix>\s*)(?P<quote>["\'])'
        r'(?P<name>[A-Za-z0-9_.-]+)\s*@\s*https?://\S+'
        r'(?P<marker>\s*;.*)?(?P=quote)(?P<trailer>,?)(?P<tail>\s*(#.*)?)$'
    )
    plain_req = re.compile(
        r'^(?P<prefix>\s*)(?P<name>[A-Za-z0-9_.-]+)\s*@\s*https?://\S+'
        r'(?P<marker>\s*;[^#\n]+)?(?P<tail>\s*(#.*)?)$'
    )

    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\n")

        m = quoted_req.match(raw)
        if m:
            lines.append(
                f"{m.group('prefix')}{m.group('quote')}{m.group('name')}"
                f"{m.group('marker') or ''}{m.group('quote')}"
                f"{m.group('trailer')}{m.group('tail')}\n")
            rewritten += 1
            continue

        m = plain_req.match(raw)
        if m:
            lines.append(
                f"{m.group('prefix')}{m.group('name')}{m.group('marker') or ''}"
                f"{m.group('tail')}\n")
            rewritten += 1
            continue

        lines.append(line)

    return "".join(lines), rewritten


p = pathlib.Path("pyproject.toml")
if not p.exists():
    print("ERROR: pyproject.toml not found", file=sys.stderr)
    sys.exit(1)

t = p.read_text()

# License: DO NOT MODIFY — upstream's PEP 639 format (license = "Apache-2.0" +
# license-files = ["LICENSE"]) generates valid Metadata-Version 2.4 that PyPI accepts.
# Any change to license fields causes metadata version mismatch → PyPI 400 rejection.

# Authors and maintainers
t = re.sub(r"^authors\s*=.*\n", "", t, flags=re.MULTILINE)
t = re.sub(r"^maintainers\s*=.*\n", "", t, flags=re.MULTILINE)
t = re.sub(
    r"^(description\s*=.*)",
    r'\1\nauthors = [{name = "Mekayel Anik", email = "mekayel.anik@gmail.com"}]'
    r'\nmaintainers = [{name = "Mekayel Anik", email = "mekayel.anik@gmail.com"}]',
    t, count=1, flags=re.MULTILINE,
)

# Project URLs: keep Homepage at upstream, update others
t = re.sub(r"Repository\s*=.*", 'Repository = "https://github.com/MekayelAnik/vllm-cpu"', t)
t = re.sub(r"Changelog\s*=.*", 'Changelog = "https://github.com/MekayelAnik/vllm-cpu/releases"', t)
if "Bug Tracker" not in t:
    t = t.replace(
        "[project.urls]",
        '[project.urls]\n"Bug Tracker" = "https://github.com/MekayelAnik/vllm-cpu/issues"',
    )

# PyPI rejects direct URL requirements in Requires-Dist metadata.
t, direct_url_count = rewrite_direct_url_requirements(t)

p.write_text(t)
print("Patched metadata: license=GPLv3, author=Mekayel Anik, URLs updated")
if direct_url_count:
    print(f"Rewrote {direct_url_count} direct URL requirement(s) for PyPI compatibility")

cpu_reqs = pathlib.Path("requirements/cpu.txt")
if cpu_reqs.exists():
    rt = cpu_reqs.read_text()
    rt, cpu_direct_url_count = rewrite_direct_url_requirements(rt)
    cpu_reqs.write_text(rt)
    if cpu_direct_url_count:
        print("Rewrote "
              f"{cpu_direct_url_count} direct URL requirement(s) in requirements/cpu.txt")
