#!/usr/bin/env python3
"""Patch pyproject.toml metadata for vllm-cpu package.

Updates license, authors, maintainers, and project URLs.
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

# License: remove PEP 639 license-files, use PEP 621 table format
t = re.sub(r"^license-files\s*=.*\n", "", t, flags=re.MULTILINE)
t = re.sub(r"^license\s*=.*", 'license = {text = "GPL-3.0-only"}', t, flags=re.MULTILINE)

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

p.write_text(t)
print("Patched metadata: license=GPL-3.0-only, author=Mekayel Anik, URLs updated")
