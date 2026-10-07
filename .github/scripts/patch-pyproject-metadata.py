#!/usr/bin/env python3
"""Patch pyproject.toml metadata for vllm-cpu package.

Updates authors, maintainers, and project URLs.
Does NOT touch license fields (upstream Apache-2.0 + PEP 639 format works as-is).
Keeps Homepage pointing to upstream vllm-project/vllm.
"""
import re
import pathlib
import sys

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
# Rewrite entries like:
#   "pkg @ https://...whl ; marker"
# to:
#   "pkg ; marker"
direct_url_req = re.compile(
    r'"([A-Za-z0-9_.-]+)\s*@\s*https?://[^"\s]+(\s*;\s*[^"]+)?"'
)
t, direct_url_count = direct_url_req.subn(
    lambda m: f'"{m.group(1)}{m.group(2) or ""}"', t
)

p.write_text(t)
print("Patched metadata: license=GPLv3, author=Mekayel Anik, URLs updated")
if direct_url_count:
    print(f"Rewrote {direct_url_count} direct URL requirement(s) for PyPI compatibility")
