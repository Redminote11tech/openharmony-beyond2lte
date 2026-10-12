#!/usr/bin/env bash
# Assemble a development boot image from measured stock header values.
# Usage: build_boot_img.sh <stock-boot.img> <Image> <oh-ramdisk.gz> <out.img>
# This does not verify bootability, mounting, signing, size limits or DTBO.
set -euo pipefail
if (($# != 4)); then
    echo "Usage: $0 <stock-boot.img> <raw-Image> <oh-ramdisk.gz> <out.img>" >&2
    exit 2
fi
python3 - "$@" <<'PY'
import gzip, os, pathlib, struct, subprocess, sys
stock, kernel, ramdisk, output = map(pathlib.Path, sys.argv[1:])
if output.resolve() in {p.resolve() for p in (stock, kernel, ramdisk)}:
    raise SystemExit('Output must differ from every input.')
if output.exists():
    raise SystemExit('Output already exists; choose a new output path.')
with stock.open('rb') as f:
    header = f.read(1648)
if len(header) != 1648 or header[:8] != b'ANDROID!':
    raise SystemExit('Expected stock Android boot image header v1.')
def u32(offset):
    return struct.unpack_from('<I', header, offset)[0]
if u32(40) != 1 or u32(36) != 2048:
    raise SystemExit('Stock header must be v1 with 2048-byte pages for beyond2lte.')
if u32(24) or u32(1632):
    raise SystemExit('Stock second stage/recovery DTBO payload requires explicit handling.')
with kernel.open('rb') as f:
    kh = f.read(64)
if len(kh) != 64 or kh[56:60] != b'ARM\x64':
    raise SystemExit('Kernel must be a raw ARM64 Image, not Image.gz.')
# Read all gzip members to verify CRC and truncation before packaging.
with gzip.open(ramdisk, 'rb') as f:
    while f.read(1024 * 1024):
        pass
cmdline = (header[64:576].split(b'\0', 1)[0] +
           header[608:1632].split(b'\0', 1)[0]).decode('ascii')
if any(t.startswith('ohos.boot.hardware=') for t in cmdline.split()):
    raise SystemExit('Stock cmdline unexpectedly already specifies OH hardware.')
cmdline = (cmdline + ' ohos.boot.hardware=beyond2lte').strip()
if len(cmdline.encode()) > 1536:
    raise SystemExit('Combined cmdline exceeds v1 capacity.')
args = [os.environ.get('BOOTIMG_TOOL', 'mkbootimg'),
        '--header_version', '1', '--kernel', str(kernel), '--ramdisk', str(ramdisk),
        '--base', '0', '--kernel_offset', hex(u32(12)),
        '--ramdisk_offset', hex(u32(20)), '--second_offset', hex(u32(28)),
        '--tags_offset', hex(u32(32)), '--pagesize', str(u32(36)),
        '--board', header[48:64].split(b'\0', 1)[0].decode('ascii'),
        '--cmdline', cmdline]
os_version = u32(44)
a, b, c = (os_version >> 25) & 127, (os_version >> 18) & 127, (os_version >> 11) & 127
month, year = os_version & 15, ((os_version >> 4) & 127) + 2000
if os_version:
    if not 1 <= month <= 12:
        raise SystemExit('Invalid stock OS patch-level encoding.')
    args += ['--os_version', f'{a}.{b}.{c}', '--os_patch_level', f'{year:04d}-{month:02d}']
args += ['-o', str(output)]
subprocess.run(args, check=True)
print(f'BOOT_IMG_ASSEMBLED_UNTESTED: {output}')
print('Preserved stock header load addresses/cmdline; no mount or gadget wiring added.')
PY
