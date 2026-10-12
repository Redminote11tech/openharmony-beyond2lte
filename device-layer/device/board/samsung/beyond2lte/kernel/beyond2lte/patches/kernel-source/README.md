# Kernel source patch sequence

0001..0008 capture the existing OpenHarmony kernel adaptation on top of the
Samsung Halium source baseline. Preserve their order.

0009 fixes the SAR fallback boot-image loader's uninitialized ramdisk offset.
It is a follow-up patch and is also applied to the local kernel source.

The existing kernel config enables CONFIG_ANDROID_SAR_RAMDISK and selects
CONFIG_ANDROID_BOOT_PARTITION="/dev/sda14". OrangeFox read-only inventory verified physical Boot at sda14; the fallback
loader itself remains untested because the diagnostic supplied a usable /init. A bootloader-supplied OpenHarmony
initramfs should contain /init and must omit skip_initramfs: when /init exists,
init/main.c avoids prepare_namespace/mount_root and the SAR fallback loader.
If /init is absent or initramfs unpacking is skipped, the kernel may wait for
and reload the boot-partition ramdisk rather than starting OpenHarmony.

The offset fix does not establish a working mount strategy, validate malformed
boot headers, or prove hardware boot compatibility.

0010 fixes the hardware-observed hilog major-245 registration collision. The
major defaults to dynamic allocation; an explicit valid `hilog.hilog_major`
parameter still requests a fixed major. The driver publishes `/dev/hilog`
through class/device registration, initializes its buffer before exposing
file operations, checks errors, unwinds partial initialization and propagates
failure from its module init. It retains the original two-minor allocation.
Hievent is unchanged.

Validation: the targeted ARM64 `drivers/staging/hilog/hilog.o` compiled with
the existing configured output/toolchain, and the exported patch was checked
against its source base. Existing ring-buffer format/type warnings remain.
The image that booted on the phone predates 0010; this follow-up has now been
linked into the rebuilt Image, but has not been tested on hardware. Runtime device permissions,
read/write behavior and allocation-failure paths require separate validation.

0011 fixes GPIO adapter allocation and HDF manager calls under the Linux
gpiolib spinlock/IRQ-disabled callback. Enumeration snapshots scalar GPIO
base/count metadata into storage allocated before the callback; controller
allocation/registration runs after enumeration returns. Device-owned controller
tracking provides rollback on partial failure and release outside gpio_lock,
including Linux chips removed after initial enumeration. A growing chip set
between sizing and snapshot passes fails cleanly rather than truncating.

Validation: targeted ARM64 gpio_adapter.o build; host harness asserts that all
allocation/register/remove/free calls happen outside callback lock context and
checks allocation/add failures, rollback, changing enumeration, invalid ranges,
empty enumeration and release after chip disappearance. Reproduce with
`python3 tools/kernel-tests/gpio_lock_context_test.py` from the workspace root.
Exported single-file
patch reverse-applicability passed. Full Image link passed; no phone test of
this fix yet;
dynamic hotplug/rebinding is not implemented by this boot-time snapshot.
