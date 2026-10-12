#!/usr/bin/env bash
# Public readable source: one queued source preparation + userspace build.
# Execute this existing public checkout only on a Crave build node.
set -euo pipefail
[[ ${CRAVE_BUILD_NODE:-} == 1 ]] || {
    echo 'Run only on an allocated Crave build node; no devspace/SSH builds.' >&2
    exit 1
}
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
BASE=/tmp/src/ohos
SRC="$BASE/ohsrc"
mkdir -p "$BASE/logs"
LOG="$BASE/logs/s10-public-userspace-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
exec > >(tee "$LOG") 2>&1
trap 'code=$?; echo "S10_PUBLIC_PIPELINE_EXIT=$code LOG=$LOG"' EXIT
echo "S10_PUBLIC_PIPELINE_STARTED $(date -u +%FT%TZ)"
echo "Public overlay checkout=$HERE"
if [[ -d $HERE/.git ]]; then
    git -C "$HERE" rev-parse HEAD
fi
df -h .
if [[ -e $SRC/device/board/oniro/system_patch/.patch_state ]]; then
    echo 'Existing patch state: preserve sources and validate complete coverage/ancestry.'
    python3 "$HERE/tools/integrate_device_layer.py" "$SRC"
    # Finish an interrupted prebuilt download only after source validation.
    (cd "$SRC" && bash build/prebuilts_download.sh)
else
    CRAVE_BUILD_NODE=1 bash "$HERE/crave-oniro-setup.sh"
fi
# Public source checkout itself is the overlay input. No payload decoding,
# reconstruction, archive extraction, inline source embedding or phone action.
BEYOND2LTE_USERSPACE_ONLY=1 CRAVE_BUILD_NODE=1 \
    bash "$HERE/crave-beyond2lte-build.sh" "$HERE"
echo 'S10_PUBLIC_USERSPACE_SUCCEEDED; inspect outputs before boot packaging.'
