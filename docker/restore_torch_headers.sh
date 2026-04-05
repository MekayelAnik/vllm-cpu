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

# Download the CUDA wheel (just for headers)
if pip download "torch==${TORCH_VER}" --no-deps --no-cache-dir -d /tmp/thdr 2>/dev/null; then
    echo "Downloaded CUDA wheel for torch==${TORCH_VER}"
elif uv pip download "torch==${TORCH_VER}" --no-deps -d /tmp/thdr 2>/dev/null; then
    echo "Downloaded CUDA wheel via uv for torch==${TORCH_VER}"
else
    echo "WARNING: Could not download CUDA wheel — torch.compile may not work"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
    rm -rf /tmp/thdr
    exit 0
fi

# Extract only include/ files from the wheel
WHL_FILE="$(find /tmp/thdr -name 'torch-*.whl' | head -1)"
if [ -z "$WHL_FILE" ]; then
    echo "WARNING: No wheel found in download"
    rm -rf /tmp/thdr
    exit 0
fi

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
" "$WHL_FILE" "$TORCH_INC"

rm -rf /tmp/thdr

if [ -f "${CPP_PREFIX}" ]; then
    echo "torch inductor headers: restored OK"
else
    echo "WARNING: headers still missing after restore attempt"
    echo "Set TORCHDYNAMO_DISABLE=1 to use eager mode as fallback"
fi
