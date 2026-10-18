#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Bounded source-access diagnostics only; no full tree sync, build or flashing.
set -euo pipefail
[[ ${CRAVE_BUILD_NODE:-} == 1 ]] || { echo 'Use an allocated Crave build node.' >&2; exit 1; }
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
BASE=/tmp/src/ohos
SRC=$BASE/ohsrc
mkdir -p "$BASE/logs"
LOG="$BASE/logs/source-recovery-$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee "$LOG") 2>&1
trap 'code=$?; echo "SOURCE_RECOVERY_EXIT=$code LOG=$LOG"' EXIT
echo "SOURCE_RECOVERY_STARTED $(date -u +%FT%TZ)"
git -C "$HERE" rev-parse HEAD
if [[ -d $SRC/.repo ]]; then
    echo 'PRIOR_SOURCE_CHECKOUT_PRESENT=yes'
else
    echo 'PRIOR_SOURCE_CHECKOUT_PRESENT=no'
fi
mkdir -p "$SRC"
df -h "$SRC" /tmp/src/android
findmnt -T "$SRC" -o TARGET,SOURCE,FSTYPE,OPTIONS
if [[ -e $BASE/source-recovery-marker ]]; then
    echo 'PRIOR_RECOVERY_MARKER_PRESENT=yes'
    cat "$BASE/source-recovery-marker"
fi
date -u +%FT%TZ > "$BASE/source-recovery-marker"
if [[ -f $SRC/build.sh && ! -d $SRC/.repo ]]; then
    echo 'Existing non-repo tree; preserve it and stop.' >&2
    exit 1
fi
if ! command -v repo >/dev/null; then
    sudo -n apt-get update
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y repo
fi
cd "$SRC"
export GIT_TERMINAL_PROMPT=0 GIT_LFS_SKIP_SMUDGE=1
repo init --depth=1 -u https://github.com/eclipse-oniro4openharmony/manifest.git \
    -b OpenHarmony-6.1-LTS -m oniro.xml --no-repo-verify
repo manifest -o "$BASE/source-recovery-manifest.xml"
python3 "$HERE/tools/crave_source_access.py" "$BASE/source-recovery-manifest.xml"
echo 'SOURCE_RECOVERY_PROBE_PASSED; review persistence and mirror report before a full sync.'
