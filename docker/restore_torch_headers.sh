#!/bin/sh
# Restore torch inductor C++ headers if missing from abi3 CPU wheel
# The cp38-abi3 CPU wheels strip torch/csrc/ and c10/ headers while per-Python
# CPU wheels (cp310, cp312, cp313, etc.) include them. This script downloads
# the matching per-Python CPU wheel and extracts the headers if missing.

set -e

TORCH_INC="$(python3 -c 'import torch,os;print(os.path.join(os.path.dirname(torch.__file__),"include"))')"
CPP_PREFIX="${TORCH_INC}/torch/csrc/inductor/cpp_prefix.h"

if [ -f "${CPP_PREFIX}" ]; then
    echo "torch inductor headers: present"
    exit 0
fi

echo "torch inductor headers missing (abi3 wheel) — downloading from per-Python CPU wheel..."
TORCH_VER="$(python3 -c 'import torch;print(torch.__version__.split("+")[0])')"
ARCH="$(uname -m)"
# Auto-detect Python version tag (cp313, cp314, cp315, etc.)
PY_TAG="$(python3 -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")')"

echo "torch=${TORCH_VER} arch=${ARCH} python=${PY_TAG}"

mkdir -p /tmp/thdr

# Try CPU index first (smaller ~180MB vs ~2GB CUDA wheel), fallback to PyPI
WHL_URL="$(python3 -c "
import json, urllib.request, sys, re

ver, arch, py_tag = sys.argv[1], sys.argv[2], sys.argv[3]
cpu_ver = ver + '%2Bcpu'  # URL-encoded +cpu

# Strategy 1: CPU index — per-Python wheel (has headers, ~180MB)
try:
    index_url = f'https://download.pytorch.org/whl/cpu/torch/'
    html = urllib.request.urlopen(index_url).read().decode()
    # Find wheel matching: torch-{ver}+cpu-{py_tag}-{py_tag}-*{arch}*.whl
    pattern = f'torch-{re.escape(ver)}\\+cpu-{py_tag}-{py_tag}-[^\"]*{arch}[^\"]*\\.whl'
    matches = re.findall(pattern, html)
    if matches:
        whl_name = matches[0].replace('+', '%2B')
        print(f'https://download.pytorch.org/whl/cpu/{whl_name}')
        sys.exit(0)
except Exception as e:
    print(f'CPU index lookup failed: {e}', file=sys.stderr)

# Strategy 2: PyPI — regular wheel (CUDA, larger but guaranteed headers)
try:
    data = json.loads(urllib.request.urlopen(f'https://pypi.org/pypi/torch/{ver}/json').read())
    for f in data.get('urls', []):
        name = f['filename']
        if arch in name and py_tag in name and name.endswith('.whl'):
            print(f['url'])
            sys.exit(0)
except Exception as e:
    print(f'PyPI lookup failed: {e}', file=sys.stderr)

# Nothing found
sys.exit(1)
" "${TORCH_VER}" "${ARCH}" "${PY_TAG}" 2>/dev/null)"

if [ -z "$WHL_URL" ]; then
    echo "WARNING: Could not find wheel with headers — torch.compile may not work"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
    rm -rf /tmp/thdr
    exit 0
fi

echo "Downloading $(echo "$WHL_URL" | grep -o '[^/]*$')..."
curl -fsSL "$WHL_URL" -o /tmp/thdr/torch.whl 2>/dev/null
if [ ! -f /tmp/thdr/torch.whl ]; then
    echo "WARNING: Download failed — torch.compile may not work"
    rm -rf /tmp/thdr
    exit 0
fi

# Extract only include/ files from the wheel (skip dirs, handle existing)
python3 -c "
import zipfile,sys,os
whl=sys.argv[1]; dest=sys.argv[2]; count=0
with zipfile.ZipFile(whl) as z:
    for m in z.namelist():
        if '/include/' not in m: continue
        parts=m.split('/include/',1)
        if len(parts)!=2 or not parts[1]: continue
        if m.endswith('/'): continue  # skip directory entries
        t=os.path.join(dest,parts[1])
        if os.path.isdir(t): continue  # skip if path is existing dir
        os.makedirs(os.path.dirname(t),exist_ok=True)
        open(t,'wb').write(z.read(m)); count+=1
    print(f'Extracted {count} header files')
" /tmp/thdr/torch.whl "$TORCH_INC"

rm -rf /tmp/thdr

if [ -f "${CPP_PREFIX}" ]; then
    echo "torch inductor headers: restored OK"
else
    echo "WARNING: headers still missing after restore attempt"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
fi
