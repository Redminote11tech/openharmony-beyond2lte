# Samsung HDC USB bring-up

The board installs `init.beyond2lte.usb.cfg` into `/system/etc/init/`; the product
installs the native `beyond2lte_usb` helper into `/vendor/bin/`. No second vendor
USB cfg is installed, avoiding duplicate jobs/imports.

The init job mounts configfs and creates a dedicated `beyond2lte_hdc` gadget,
links `ffs.hdc`, and mounts FunctionFS at HDC's `/dev/usb-ffs/hdc`. The native
service checks the actual FunctionFS mount and gadget paths, discovers exactly
one entry under `/sys/class/udc`, and publishes preparation status. It refuses
multiple controllers and waits up to 30 seconds for a controller to register.
The readiness job enables HDC USB and starts hdcd. The helper binds the detected
UDC only after `sys.usb.ffs.ready.hdc=1`; it unbinds when that readiness or USB
mode is lost, and rebinds after daemon reconnection. Every poll rereads the
actual gadget `UDC` attribute: Samsung FunctionFS close can unregister the
gadget even when a fast readiness transition is missed. A helper restart adopts
an existing expected binding; an unexpected controller causes refusal, without
unbinding it. I/O/bind errors log their errno (repeated identical errors are
limited). The service explicitly disables its init sandbox. No Exynos address or
MediaTek role-switch sysfs path is hardcoded. Its private gadget does not use
upstream generic `g1` triggers or OH init parameter-string expansion.

Live read-only OrangeFox evidence (`device-inventory.txt`, 2026-10-10):

- Exactly one registered UDC: `10c00000.dwc3`, with recovery gadget `g1` bound
  and configured. Configfs is mounted at `/config`; recovery has its own
  FunctionFS functions, including ADB/fastboot/MTP.
- `/dev/graphics/fb0` and `fb1` exist with `root:graphics` ownership; fb0 reports
  32-bit pixels and virtual size `1440,6080`. This is recovery evidence, not
  proof that OH display services can use these nodes.

The discovery helper deliberately continues to discover the registered UDC at
runtime instead of embedding the recovery name. Recovery's `g1` must remain
intact: do not execute this OH setup/helper in recovery. A UDC occupied by `g1`
will reject the private gadget bind; the helper reports the failure and never
unbinds `g1`. No recovery gadget or phone USB state was changed during this work.

Evidence from local source:

- `kernel/out-beyond2lte/.config`: DWC3 dual-role, Exynos DWC3,
  `CONFIG_USB_CONFIGFS=y`, `CONFIG_USB_CONFIGFS_F_FS=y`, `CONFIG_USB_F_FS=y`.
- Samsung kernel `drivers/usb/gadget/function/f_fs.c`: FunctionFS superblock
  magic `0x0a647361`; descriptor readiness is required before binding.
- `oh-kernel-delta/hdc-src/src/daemon/daemon_usb.cpp`: hdcd publishes
  `sys.usb.ffs.ready.hdc=1` after endpoint descriptor initialization.
- `oh-kernel-delta/hdc-src/src/daemon/usb_ffs.h`: HDC FunctionFS base path.
- Existing Oniro/RK3568 USB cfg: gadget/config/string/OS-descriptor layout and
  FunctionFS mount ownership `uid=2000,gid=2000`.
- Samsung `drivers/usb/gadget/configfs.c` and `composite.c`: configfs MaxPower
  is supplied in milliamps. `500` means 500 mA; the kernel encodes descriptor
  units as 2 mA below SuperSpeed and 8 mA at SuperSpeed.
- Existing HDC C++ implementation and GN: `SetParameter`/`GetParameter` via
  `parameter.h` and `init:libbegetutil`.

`12D1:5000` is the existing upstream HDC **development** identity, not an
allocated Samsung/OpenHarmony product identity. The development serial is fixed
as `beyond2lte-dev`; multiple phones need unique serials before simultaneous use.
OS descriptors use the standard `MSFT100` signature. Product distribution needs
an appropriate allocated USB identity.

Validation here: JSON parsing; native C strict host compilation with stubbed
parameter API; absent/one/multiple-controller discovery; first bind, helper
restart adoption, rapid FunctionFS-close/reconnect rebind, not-ready unbind,
foreign-controller refusal without mutation, and missing-attribute errno.
Re-run `python3 tests/usb_lifecycle_test.py` from this directory. Earlier checks
also verified refusal when configfs/FunctionFS is absent. No privileged host mounts or real phone writes
were executed. Host compilation does not validate the OH target ABI/link or
parameter/SELinux policy. Full source build and phone runtime must verify:
controller registration in peripheral role, init command ordering and duplicate
upstream triggers, mount ownership, helper service permissions, HDC parameter
DAC, descriptor readiness, host enumeration and connection/reconnection.
