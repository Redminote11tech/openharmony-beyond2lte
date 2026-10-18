# Submit this readable command through crave run; do not execute locally or in devspace.
set -eu
SOURCE_URL=https://github.com/Redminote11tech/openharmony-beyond2lte.git
REVISION=b3424dbf08d218afe38bf2dc414b52aa3d13a4ad
BASE=/tmp/src/ohos
CHECKOUT=$BASE/public-port
# Provision only this new directory. Never change ownership of existing trees.
if [ -L "$BASE" ]; then
    echo 'Refusing a symbolic-link source directory.' >&2
    exit 1
fi
if [ -e "$BASE" ]; then
    test -d "$BASE"
    test -w "$BASE"
else
    if [ -w "$(dirname "$BASE")" ]; then
        mkdir -m 0755 -- "$BASE"
    else
        sudo -n mkdir -m 0755 -- "$BASE"
        sudo -n chown --no-dereference "$(id -u):$(id -g)" "$BASE"
    fi
fi
test ! -L "$BASE"
test -w "$BASE"
if [ -e "$CHECKOUT" ]; then
    test -d "$CHECKOUT/.git"
    test "$(git -C "$CHECKOUT" remote get-url origin)" = "$SOURCE_URL"
    test -z "$(git -C "$CHECKOUT" status --porcelain)"
else
    git clone --depth 1 "$SOURCE_URL" "$CHECKOUT"
fi
git -C "$CHECKOUT" fetch --depth 1 origin "$REVISION"
git -C "$CHECKOUT" checkout --detach "$REVISION"
CRAVE_BUILD_NODE=1 bash "$CHECKOUT/crave-beyond2lte-pipeline.sh"
