# OpenHarmony/Oniro Samsung Galaxy S10+ source adaptation

Public source overlay for the Exynos9820 `beyond2lte` board and product on
OpenHarmony/Oniro 6.1-LTS. This is an incomplete port: source integration and
userspace compilation do not establish phone boot, graphics, audio, modem or
other hardware support. There is no firmware dump, kernel binary, phone backup,
credential, generated build log, encoded payload or flashable image here.

## Scope

- `device-layer/device/board/samsung/beyond2lte`: cfg-only Samsung board group,
  init overlays, kernel prebuilt/boot assembly helpers and readable source patches.
- `device-layer/vendor/samsung/beyond2lte`: product definition, native USB
  helper/tests, init/config metadata and inherited upstream hardware references.
- `kernel-config/beyond2lte/khdf`: canonical minimal kernel HDF source config
  (KEVENT plus automatic Linux GPIO/I2C wrappers). No compiled HCB is included.
- `tools/integrate_device_layer.py`: checks complete shared patch coverage,
  post-patch ancestry and subsystem registration before applying a fresh overlay.
- Three readable Crave scripts: source setup, one userspace build and their
  sequential pipeline. All source downloads/builds belong on a queued node.

Other-device kernel examples remain upstream references and are not selected
by the Samsung cfg-only board group. Inherited Volla flashing helpers are not
Samsung flashing instructions. Never use them to install this port.

The upstream boot-picture archive is not copied into this repository. Its
active GN target reads the existing public asset directly from
`//vendor/oniro/hybris_generic/custom_conf/bootanimation/bootpic.zip` in the
matching prepared Oniro source checkout. The staged asset was compared against
that upstream reference before replacing the source label.

Kernel patches 0004 and 0007 have been filtered to remove generated objects,
build metadata, Git binary diff blocks and unrelated upstream encoding
test/tool blocks. Their remaining source hunks and
copyright notices are preserved. They are **not byte-identical to the historical
patch set**; `SOURCE-FILTERS.json` lists every removed path. They are source
provenance for a future separately verified kernel build, not a complete
kernel build recipe or a claim that the public filtered series has been built.

## Source provenance and licenses

Per-file notices are retained and take precedence over this summary.
`LICENSE-MANIFEST.json` records a license classification and SHA256 for each
published source file. Full license texts are under `LICENSES/`.

- Board/product baseline: Eclipse Oniro `device_board_oniro` and `vendor_oniro`,
  branch `OpenHarmony-6.1-LTS`, Apache-2.0 except files with explicit GPL notices:
  https://github.com/eclipse-oniro4openharmony/device_board_oniro
  https://github.com/eclipse-oniro4openharmony/vendor_oniro
- Shared SoC and graphics adaptation: the complete published Oniro manifest:
  https://github.com/eclipse-oniro4openharmony/manifest/tree/OpenHarmony-6.1-LTS
  https://github.com/eclipse-oniro4openharmony/device_soc_oniro
- Samsung kernel patch baseline: UBports community Samsung S10 kernel,
  `halium-12.0`; Linux kernel GPL-2.0, with imported HDF files retaining their
  GPL-2.0/BSD-3-Clause notices:
  https://gitlab.com/ubports/porting/community-ports/android10/samsung-galaxy-s10/kernel-samsung-exynos9820
- OpenHarmony HDF: https://github.com/openharmony/drivers_hdf_core
- Carrier configuration derives from AOSP `device/sample`, `android14-release`,
  commit `89b86021ff1ee7977a4e979eb70d5d7cec72a4aa`, Apache-2.0:
  https://android.googlesource.com/device/sample/

New integration scripts/documentation and Samsung source configurations in
this repository are Apache-2.0. Kernel patch files modify GPL-covered source;
embedded notices remain authoritative. Publication of this source repository
does not authorize redistribution of separate proprietary vendor blobs.

## Build on Crave

Read `AGENTS.md` and `CRAVE-RULES.md`, verify the queue is clear and use the
existing workspace. Clone this public repository normally on the allocated
build node, inspect/pin its Git revision, then execute its public script:

```sh
CRAVE_BUILD_NODE=1 bash /path/to/openharmony-beyond2lte/crave-beyond2lte-pipeline.sh
```

The pipeline prepares/reuses `/tmp/src/ohos/ohsrc`, validates upstream patch
state and downloads missing prebuilts, then applies this readable checkout
and builds exactly one product using
`bash ./build.sh --product-name beyond2lte --ccache`. It explicitly selects
userspace-only mode: no kernel Image is required or validated, and no boot
image is assembled. Existing Samsung overlay destinations are refused rather
than silently overwritten. Logs remain under `/tmp/src/ohos/logs`.

The script itself does not submit a job, initialize/publish this repository or
flash a phone. Missing dependencies, partial patches and compiler/build failures
must be resolved from retained diagnostics without deleting the source tree.
