#!/usr/bin/env bash
# Queue-only follow-up payload. Never execute in devspace/SSH or locally.
# Usage on an allocated build node:
# CRAVE_BUILD_NODE=1 bash crave-beyond2lte-build.sh /path/to/samsung-payload
# This script does not submit a job, sync sources, clean output, or flash.
set -euo pipefail
[[ ${CRAVE_BUILD_NODE:-} == 1 ]] || {
    echo 'Refusing execution: use only as a queued Crave build-node payload with CRAVE_BUILD_NODE=1.' >&2
    exit 1
}
(($# == 1)) || { echo "Usage: $0 <samsung-payload-directory>" >&2; exit 2; }
BASE=/tmp/src/ohos
SRC="$BASE/ohsrc"
PAYLOAD=$(realpath -e -- "$1")
KERNEL="$PAYLOAD/prebuilts/kernel/beyond2lte"
INTEGRATOR="$PAYLOAD/tools/integrate_device_layer.py"
OVERLAY="$PAYLOAD/device-layer"
HELPER="$OVERLAY/device/board/samsung/beyond2lte/kernel/beyond2lte/build_kernel.sh"
USERSPACE_ONLY=${BEYOND2LTE_USERSPACE_ONLY:-0}
[[ $USERSPACE_ONLY == 0 || $USERSPACE_ONLY == 1 ]] || {
    echo 'BEYOND2LTE_USERSPACE_ONLY must be 0 or 1.' >&2; exit 2;
}
command -v python3 >/dev/null
command -v flock >/dev/null
[[ -d $SRC/.repo && -f $SRC/build.sh && -f $BASE/oniro-resolved.xml ]] || {
    echo 'Source preparation is incomplete: missing Git manifest checkout/build.sh/resolved manifest.' >&2
    exit 1
}
[[ -x $SRC/prebuilts/clang/ohos/linux-x86_64/llvm/bin/clang ]] || {
    echo 'Downloaded Oniro compiler is missing; finish source/prebuilt preparation first.' >&2
    exit 1
}
[[ -f $INTEGRATOR && -f $HELPER ]] || {
    echo 'Payload incomplete: need integrator and device-layer.' >&2
    exit 1
}
if [[ $USERSPACE_ONLY == 0 ]]; then
    [[ -f $KERNEL/Image && -f $KERNEL/.config ]] || {
        echo 'Missing kernel prebuilt; explicit BEYOND2LTE_USERSPACE_ONLY=1 permits userspace compilation only.' >&2
        exit 1
    }
fi
[[ ! -e $SRC/device/board/samsung/beyond2lte && ! -e $SRC/vendor/samsung/beyond2lte ]] || {
    echo 'Samsung destinations already exist; review the existing overlay before updating. No files replaced.' >&2
    exit 1
}
# Check the recorded complete manifest rather than silently inventing missing
# repositories. Upstream revisions and patch ancestry are checked separately
# by the integrator. A resolved manifest does not by itself prove a build.
python3 - "$BASE/oniro-resolved.xml" <<'PY'
import pathlib, re, sys, xml.etree.ElementTree as ET
root = ET.parse(pathlib.Path(sys.argv[1])).getroot()
projects = {p.get('path', p.get('name')):p for p in root.findall('project')}
required = ('build', 'device/board/oniro', 'device/soc/oniro', 'vendor/oniro',
            'third_party/libhybris', 'third_party/android-headers')
for path in required:
    project = projects.get(path)
    if project is None or not re.fullmatch(r'[0-9a-f]{40}', project.get('revision', '')):
        raise SystemExit(f'Resolved manifest is incomplete/unpinned: {path}')
print('Resolved required source revisions present; build compatibility unverified.')
PY
# Local lock supplements the user-facing one-job-at-a-time queue requirement;
# it is not a substitute for checking that no other queue job is active.
exec 9> "$BASE/beyond2lte-build.lock"
flock -n 9 || { echo 'Another beyond2lte recipe holds this workspace lock.' >&2; exit 1; }
LOG_DIR="$BASE/logs/beyond2lte-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p -- "$LOG_DIR"
exec > >(tee "$LOG_DIR/recipe.log") 2>&1
trap 'result=$?; echo "BUILD_RECIPE_EXIT=$result LOG_DIR=$LOG_DIR"' EXIT
echo "Source=$SRC Payload=$PAYLOAD Logs=$LOG_DIR"
# Both checks run before any Samsung source files are installed. The integrator
# refuses incomplete/malformed patch state, absent post-patch Git ancestry and
# conflicting registrations. The helper checks raw Image format and required
# OpenHarmony kernel config, not phone runtime behavior.
python3 "$INTEGRATOR" "$SRC"
if [[ $USERSPACE_ONLY == 0 ]]; then
    bash "$HELPER" --prebuilt-dir "$KERNEL" --check-only
    sha256sum "$KERNEL/Image" "$KERNEL/.config" > "$LOG_DIR/kernel-input.sha256"
else
    echo 'Explicit userspace-only build: no kernel binary was supplied or validated.'
    echo 'No boot image or flashable package will be assembled.'
fi
cp -- "$BASE/oniro-resolved.xml" "$LOG_DIR/oniro-resolved.xml"
cp -- "$SRC/device/board/oniro/system_patch/.patch_state" "$LOG_DIR/oniro-patch-state.tsv"
python3 "$INTEGRATOR" "$SRC" --apply
cd -- "$SRC"
echo 'Building ONE Samsung userspace product. No kernel compilation or boot-image assembly.'
# These options are demonstrated in the matching Oniro phone build reference.
# GN/product validation happens inside this build; no GN success is presumed.
bash ./build.sh --product-name beyond2lte --ccache
echo "BEYOND2LTE_PRODUCT_BUILD_SUCCEEDED; inspect $SRC/out/beyond2lte before packaging."
echo 'No flashable boot.img is declared; kernel assembly and installation are separate.'
