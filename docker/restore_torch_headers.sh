#!/bin/sh
# Restore torch inductor C++ headers if missing from CPU wheel
# CPU wheels from download.pytorch.org/whl/cpu don't ship torch/csrc/ or c10/ headers
# needed by torch.compile (inductor JIT). This script downloads them from the
# matching CUDA wheel on PyPI if they're missing.

set -e

TORCH_INC="$(python3 -c 'import torch,os;print(os.path.join(os.path.dirname(torch.__file__),"include"))')"
CPP_PREFIX="${TORCH_INC}/torch/csrc/inductor/cpp_prefix.h"

if [ -f "${CPP_PREFIX}" ]; then
    echo "torch inductor headers: present"
    exit 0
fi

echo "torch inductor headers missing — downloading from CUDA wheel..."
TORCH_VER="$(python3 -c 'import torch;print(torch.__version__.split("+")[0])')"

mkdir -p /tmp/thdr

# Download CUDA wheel using curl + PyPI JSON API (pip/uv may be removed by cleanup)
echo "Looking up torch==${TORCH_VER} wheel URL from PyPI..."
ARCH="$(uname -m)"
PY_VER="$(python3 -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")')"

WHL_URL="$(python3 -c "
import json, urllib.request, sys
ver, arch, py = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.loads(urllib.request.urlopen(f'https://pypi.org/pypi/torch/{ver}/json').read())
for f in data.get('urls', []):
    name = f['filename']
    if arch in name and py in name and name.endswith('.whl') and 'include' not in name.lower():
        print(f['url']); break
" "${TORCH_VER}" "${ARCH}" "${PY_VER}" 2>/dev/null)"

if [ -z "$WHL_URL" ]; then
    echo "WARNING: Could not find CUDA wheel URL — torch.compile may not work"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
    rm -rf /tmp/thdr
    exit 0
fi

echo "Downloading $(basename "$WHL_URL")..."
curl -fsSL "$WHL_URL" -o /tmp/thdr/torch.whl 2>/dev/null
if [ ! -f /tmp/thdr/torch.whl ]; then
    echo "WARNING: Download failed — torch.compile may not work"
    rm -rf /tmp/thdr
    exit 0
fi

# Extract only include/ files from the wheel
python3 -c "
import zipfile,sys,os
whl=sys.argv[1]; dest=sys.argv[2]
with zipfile.ZipFile(whl) as z:
    members=[n for n in z.namelist() if '/include/' in n]
    for m in members:
        parts=m.split('/include/',1)
        if len(parts)==2 and parts[1]:
            t=os.path.join(dest,parts[1])
            os.makedirs(os.path.dirname(t),exist_ok=True)
            open(t,'wb').write(z.read(m))
    print(f'Extracted {len(members)} header files')
" /tmp/thdr/torch.whl "$TORCH_INC"

rm -rf /tmp/thdr

if [ -f "${CPP_PREFIX}" ]; then
    echo "torch inductor headers: restored OK"
else
    echo "WARNING: headers still missing after restore attempt"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
fi
