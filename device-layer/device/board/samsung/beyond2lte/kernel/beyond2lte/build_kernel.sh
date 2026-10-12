#!/usr/bin/env bash
# Stage the already built Samsung kernel; no network or compilation here.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$HERE/../../../../../.." && pwd)
PREBUILT=${BEYOND2LTE_KERNEL_PREBUILT:-$ROOT_DIR/prebuilts/kernel/beyond2lte}
OUT_DIR=${BEYOND2LTE_KERNEL_OUT:-$ROOT_DIR/out/kernel/beyond2lte}
usage() {
    echo "Usage: $0 [--prebuilt-dir DIR] [--out-dir DIR] [--check-only]"
    echo "DIR must contain Image (or arch/arm64/boot/Image) and .config."
}
CHECK_ONLY=0
while (($#)); do
    case "$1" in
        --prebuilt-dir|--out-dir)
            (($# >= 2)) || { usage >&2; exit 2; }
            if [[ $1 == --prebuilt-dir ]]; then PREBUILT=$2; else OUT_DIR=$2; fi
            shift 2 ;;
        --check-only) CHECK_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
IMAGE="$PREBUILT/Image"
[[ -f $IMAGE ]] || IMAGE="$PREBUILT/arch/arm64/boot/Image"
[[ -f $IMAGE && -f $PREBUILT/.config ]] || {
    echo "Missing raw Image or .config in $PREBUILT; stage the verified kernel explicitly." >&2
    exit 1
}
python3 - "$IMAGE" <<'PY'
import sys
with open(sys.argv[1], 'rb') as f:
    header = f.read(64)
if len(header) != 64 or header[56:60] != b'ARM\x64':
    raise SystemExit('Expected an uncompressed ARM64 Image (ARM64 header magic).')
PY
while IFS= read -r option; do
    [[ $option == CONFIG_*=y || $option == CONFIG_HDF_SUPPORT_LEVEL=2 || $option == CONFIG_HILOG_BUFFER_SIZE=4096 ]] || continue
    grep -qxF "$option" "$PREBUILT/.config" || {
        echo "Prebuilt config missing: $option" >&2; exit 1;
    }
done < "$HERE/config/openharmony.config"
if ((CHECK_ONLY)); then
    echo "KERNEL_PREBUILT_VALID: $IMAGE (format/config only; runtime unverified)"
    exit 0
fi
mkdir -p -- "$OUT_DIR/arch/arm64/boot"
install -m 0644 -- "$IMAGE" "$OUT_DIR/arch/arm64/boot/Image"
install -m 0644 -- "$PREBUILT/.config" "$OUT_DIR/.config"
if [[ -f $PREBUILT/System.map ]]; then
    install -m 0644 -- "$PREBUILT/System.map" "$OUT_DIR/System.map"
fi
(cd -- "$OUT_DIR" && sha256sum arch/arm64/boot/Image .config > prebuilt.sha256)
echo "KERNEL_PREBUILT_STAGED: $OUT_DIR/arch/arm64/boot/Image"
echo "DTBO assembly is separate: no individual .dtbo is copied or declared flashable."
