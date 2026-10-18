#!/usr/bin/env bash
# SOURCE PREPARATION ONLY. Execute this payload through crave run on a build
# node, never inside devspace/SSH. Preserve /tmp/src/ohos workspace identity.
set -euxo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
test "${CRAVE_BUILD_NODE:-}" = 1 || { echo 'Run only as a Crave build-node payload (CRAVE_BUILD_NODE=1).'; exit 1; }
BASE=/tmp/src/ohos
SRC="$BASE/ohsrc"
mkdir -p "$SRC"
cd "$SRC"
df -h .
# Refuse another full download into unverified container-root storage.
# A supported persistent volume must be provisioned at the stable source path.
mount_target=$(findmnt -n -T "$SRC" -o TARGET)
if [[ -z $mount_target || $mount_target == / ]]; then
    echo 'Full sync blocked: source is on container root; persistent storage must be established.' >&2
    exit 1
fi
available_kib=$(df -Pk "$SRC" | awk 'NR==2 {print $4}')
if (( available_kib < 180 * 1024 * 1024 )); then
    echo 'Full sync blocked: require 180 GiB free as a conservative phone-build budget.' >&2
    exit 1
fi
# Refuse to mix the old release-tarball layout with a Git source checkout.
if test -f build.sh && ! test -d .repo; then
    echo 'Existing release source tree: stop and review it; no files were removed.'
    exit 1
fi
if test -e device/board/oniro/system_patch/.patch_state; then
    echo 'Patch state already exists: validate its coverage before continuing.'
    exit 1
fi
# Install missing cold-build host tools only on this queued build node.
packages=(git-lfs autoconf automake autotools-dev m4 libtool libtool-bin libltdl-dev cmake)
command -v repo >/dev/null || packages+=(repo)
missing=()
for package in "${packages[@]}"; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' || missing+=("$package")
done
if ((${#missing[@]})); then
    sudo -n apt-get update
    sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
fi
command -v repo
command -v git-lfs
repo init --depth=1 -u https://github.com/eclipse-oniro4openharmony/manifest.git \
    -b OpenHarmony-6.1-LTS -m oniro.xml --no-repo-verify
export GIT_TERMINAL_PROMPT=0
repo manifest -o "$BASE/oniro-source-manifest.xml"
python3 "$HERE/tools/crave_source_access.py" "$BASE/oniro-source-manifest.xml" --fetch-all
# Expensive remaining source transfer starts only after the known failures pass.
repo sync -c -j4 --fail-fast
repo forall -e -c 'git lfs pull'
repo manifest -r -o "$BASE/oniro-resolved.xml"
# Patch helper requires an explicit automation commit identity, not a global
# change to the user's Git config. Check an existing state before rerunning it.
GIT_AUTHOR_NAME='Samsung OpenHarmony build' GIT_AUTHOR_EMAIL='build@localhost' \
GIT_COMMITTER_NAME='Samsung OpenHarmony build' GIT_COMMITTER_EMAIL='build@localhost' \
    bash device/board/oniro/system_patch/do_patch.sh
bash build/prebuilts_download.sh
df -h .
echo ONIRO_SOURCE_READY
