# Samsung kernel prebuilt integration

The first userspace build consumes the existing OH-patched 4.14 kernel. It does
not clone Halium, reapply patches, wipe a kernel workspace or start compilation.

In an OpenHarmony source root, place a public/staged prebuilt at
`prebuilts/kernel/beyond2lte/` containing `Image` and `.config`, or pass the
existing kernel output directory explicitly:

```sh
bash device/board/samsung/beyond2lte/kernel/beyond2lte/build_kernel.sh \
  --prebuilt-dir /path/to/out-beyond2lte --check-only
bash device/board/samsung/beyond2lte/kernel/beyond2lte/build_kernel.sh \
  --prebuilt-dir /path/to/out-beyond2lte
```

This stages `out/kernel/beyond2lte/arch/arm64/boot/Image`, `.config`, optional
`System.map`, and a SHA-256 manifest. ARM64 raw-image magic and the minimum OH
feature contract are validated. This is format/config validation, not runtime
validation. The complete config remains authoritative; the fragment is only a
minimum contract. Patches remain as provenance for a future reproducible kernel
source build.

Boot assembly is a separate explicit step after an OH ramdisk exists:

```sh
bash device/board/samsung/beyond2lte/kernel/beyond2lte/build_boot_img.sh \
  /path/to/stock-boot.img /path/to/Image /path/to/oh-ramdisk.gz /path/to/new-boot.img
```

Set `BOOTIMG_TOOL` to a compatible mkbootimg executable if needed. The script
reads the stock v1/2048-byte header and preserves its load addresses, board, OS
version, patch level and complete cmdline; it appends only
`ohos.boot.hardware=beyond2lte`. It rejects compressed kernels, corrupt gzip
ramdisks, output overwrite and unsupported second/recovery-DTBO payloads. No
required mounts or UDC are guessed. No DTBO image is generated, and individual
DTBO files must not be treated as complete flashable partition images.

Open blockers: actual ramdisk init/install layout, OpenHarmony mount syntax and
required partitions, Samsung gadget/functionfs wiring, verified combined DTBO,
Samsung boot signing/partition capacity and graphics HDI. There is deliberately
no GN target that packages a boot image automatically while these are unresolved.
