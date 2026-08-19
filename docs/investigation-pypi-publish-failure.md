# Investigation: PyPI Publishing Failure for v0.17.1 and v0.18.0

## Root Cause: Setuptools License Metadata Version Mismatch

The PyPI `400 Bad Request - Invalid distribution file` error is caused by **setuptools generating `License-File` headers in METADATA while declaring `Metadata-Version: 2.1`**. PyPI rejects this because `License-File` was introduced in Metadata-Version 2.4 (PEP 639).

## Detailed Explanation

### The upstream vLLM pyproject.toml (all three versions: v0.17.1, v0.18.0, v0.19.0)

All three upstream versions use identical license configuration:
```toml
[build-system]
requires = ["setuptools>=77.0.3,<81.0.0", ...]

[project]
license = "Apache-2.0"          # PEP 639 SPDX string format
license-files = ["LICENSE"]     # PEP 639 license-files
```

With setuptools >= 77.0.3, this PEP 639 configuration generates:
```
Metadata-Version: 2.4
License-Expression: Apache-2.0
License-File: LICENSE
```

This is **valid** and PyPI accepts it.

### What the metadata patch does (v0.17.1, v0.18.0 builds)

The `build_wheels.sh` metadata patch transforms the license configuration:

1. **Removes** `license-files = ["LICENSE"]` from `[project]` section
2. **Replaces** `license = "Apache-2.0"` with `license = {text = "GPL-3.0-only"}` (deprecated PEP 621 table format)
3. **Adds** `license-files = []` under `[tool.setuptools]` to disable auto-inclusion

After patching, pyproject.toml contains:
```toml
[build-system]
requires = ["setuptools>=77.0.3,<81.0.0", ...]

[project]
license = {text = "GPL-3.0-only"}    # Deprecated PEP 621 table format
# (license-files removed)

[tool.setuptools]
license-files = []                    # Intended to suppress auto-include
```

### The problem: setuptools >= 77 behavior with mixed formats

When setuptools >= 77 encounters the deprecated `license = {text = "..."}` format:

1. It emits a `SetuptoolsDeprecationWarning` about the table format
2. It generates a classic `License:` header (not `License-Expression:`)
3. It declares `Metadata-Version: 2.1` (since it's not using PEP 639 path)
4. **BUT** it STILL auto-includes `License-File` entries if any files match the default glob patterns (`LICEN[CS]E*`, `COPYING*`, `NOTICE*`, `AUTHORS*`)

The `license-files = []` under `[tool.setuptools]` is a **setuptools-specific** configuration, but it may NOT properly override the `[project]` level behavior in setuptools >= 77. The upstream vLLM repository has a `LICENSE` file, so setuptools auto-detects and includes it.

**Result**: The generated METADATA contains:
```
Metadata-Version: 2.1
License: GPL-3.0-only
License-File: LICENSE         <-- INVALID! License-File requires Metadata-Version 2.4
```

PyPI validates this and rejects with `400 Bad Request`:
> `400 license-file introduced in metadata version 2.4, not 2.1`

(The "None" in the error message is PyPI not exposing the detailed reason in all cases.)

### Why v0.19.0 succeeded

v0.19.0 was built from commit `7ce6871` which had a **broken** metadata patch. The patch used a `printf`-based Python script approach that failed silently inside `bash -exc`. Because the patch failed silently:

1. The pyproject.toml was left **unmodified** (upstream Apache-2.0 license)
2. Upstream format `license = "Apache-2.0"` + `license-files = ["LICENSE"]` is valid PEP 639
3. Setuptools >= 77 correctly generates `Metadata-Version: 2.4` + `License-Expression: Apache-2.0` + `License-File: LICENSE`
4. PyPI accepts this valid metadata

## The "predicate: null" Attestation Red Herring

The `"predicate":null` in the DSSE payload and the attestation issues are a **separate, secondary problem** that was already addressed in commit `f057aa5` ("fix: disable attestations"). The attestation issue would cause problems with `pypa/gh-action-pypi-publish` using Trusted Publishing, but the current publish workflow uses **twine with API tokens** (not gh-action-pypi-publish), so attestations are not relevant to the current failure.

However, it's worth noting that twine itself (version 6.x) also validates metadata and may reject wheels with `License-File` in `Metadata-Version: 2.1`. The `twine check` step would catch this, but the `twine upload` step may also fail at the PyPI server side.

## Fix Options

### Option A: Keep upstream license metadata (recommended, simplest)
Do NOT modify the license fields at all. Leave upstream's PEP 639 format intact:
```toml
license = "Apache-2.0"
license-files = ["LICENSE"]
```
This generates valid `Metadata-Version: 2.4` with `License-Expression: Apache-2.0`.

### Option B: Pin setuptools < 77 in build-system requires
Override the build-system requires to use setuptools < 77 (which does not support PEP 639):
```toml
[build-system]
requires = ["setuptools>=74,<77", ...]
```
With setuptools < 77:
- `license = {text = "GPL-3.0-only"}` generates `Metadata-Version: 2.1` + `License: GPL-3.0-only`
- No `License-File` or `License-Expression` headers are emitted
- PyPI accepts this

**Caveat**: This conflicts with upstream's `setuptools>=77.0.3` requirement. You'd need to also patch the build-system requires.

### Option C: Use PEP 639 format for custom license
Instead of the deprecated table format, use the SPDX string format that setuptools >= 77 expects:
```toml
[project]
license = "GPL-3.0-only"
license-files = []              # Empty list at [project] level, not [tool.setuptools]
```
This tells setuptools >= 77 to generate:
```
Metadata-Version: 2.4
License-Expression: GPL-3.0-only
```
No `License-File` headers (since we specified empty list at the correct level).

**Important**: The empty `license-files` must be at `[project]` level, not `[tool.setuptools]` level.

### Option D: Remove LICENSE file before build
After cloning vLLM source but before building, delete the LICENSE file:
```bash
rm -f LICENSE LICENCE COPYING NOTICE AUTHORS
```
This prevents setuptools from auto-detecting and including license files, avoiding the `License-File` header entirely.

## Recommended Fix

**Option C** is the cleanest approach. Update the metadata patch in `build_wheels.sh`:

```bash
# Instead of:
sed -i 's/^license[[:space:]]*=.*/license = {text = "GPL-3.0-only"}/' pyproject.toml

# Use:
sed -i 's/^license[[:space:]]*=.*/license = "GPL-3.0-only"/' pyproject.toml
```

And for license-files, ensure the empty list is at `[project]` level:
```bash
# Instead of adding to [tool.setuptools]:
# license-files = []

# Keep it at [project] level:
sed -i 's/^license-files[[:space:]]*=.*/license-files = []/' pyproject.toml
```

This ensures:
1. `license = "GPL-3.0-only"` triggers PEP 639 path in setuptools >= 77
2. `license-files = []` at `[project]` level properly disables license file inclusion
3. Generated metadata: `Metadata-Version: 2.4` + `License-Expression: GPL-3.0-only` (no `License-File`)
4. PyPI validates and accepts

## References

- [setuptools issue #4759](https://github.com/pypa/setuptools/issues/4759) - `tool.setuptools.license-files` results in invalid metadata
- [twine issue #1216](https://github.com/pypa/twine/issues/1216) - Invalid Distribution Metadata: unrecognized or malformed field: 'license-file'
- [uv issue #9513](https://github.com/astral-sh/uv/issues/9513) - Uploads fail due to setuptools using wrong metadata version for license-file
- [setuptools issue #4903](https://github.com/pypa/setuptools/issues/4903) - Migration guide for PEP 639 license expression
- [PEP 639](https://peps.python.org/pep-0639/) - Improving License Clarity with Better Package Metadata
- [Eric Ma's blog](https://ericmjl.github.io/blog/2025/3/1/how-to-fix-pypi-upload-errors-related-to-license-metadata/) - How to fix PyPI upload errors related to license metadata
