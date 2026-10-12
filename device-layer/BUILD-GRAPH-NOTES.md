# Samsung board and product build graph

The staged board bundle selects `//device/board/samsung/beyond2lte:beyond2lte_group`.
The Samsung product selects `device_beyond2lte`, `product_beyond2lte`, and
Oniro's published `oniro_soc_products/hybris_generic_soc` component. Product
prebuilt targets use `product_beyond2lte` throughout. Samsung-local product
bundle targets resolve under `vendor/samsung/beyond2lte`.

## Required source registrations

Use a matching OpenHarmony/Oniro 6.1 source baseline and its shared patches.
The staged tree alone is not an independent OpenHarmony distribution.
`device.gni` deliberately retains `soc_company = "oniro"` and
`soc_name = "hybris_generic"`; it requires the actual published
`device/soc/oniro/hybris_generic` source rather than a renamed empty stub.

Register these entries in the source baseline's `build/subsystem_config.json`
without replacing existing entries:

```json
{
  "device_beyond2lte": {
    "path": "device/board/samsung/beyond2lte",
    "name": "device_beyond2lte"
  },
  "product_beyond2lte": {
    "path": "vendor/samsung/beyond2lte",
    "name": "product_beyond2lte"
  },
  "oniro_soc_products": {
    "path": "device/soc/oniro",
    "name": "oniro_soc_products"
  }
}
```

The Oniro build patch
`system_patch/patches/build/0002-build-register-oniro_soc_products-hybris_generic-as-.patch`
is the existing upstream example for the SoC registration. Confirm product
discovery and GN generation against the complete patched source tree before
claiming a successful integration.

## Intentional shared dependencies

`vendor/oniro/oniro-haps` supplies app targets, its GN options, and the
preinstall-list generator. `vendor/oniro/wallpaper` supplies wallpaper targets.
These imports and targets stay under Oniro paths and must be present alongside
the Samsung product. `third_party/libhybris` and the SoC HDIs are also required.
The shared SoC still contains hardware adapters that require Samsung review;
selecting it does not establish compatibility with Exynos vendor HALs.

## Runtime limits

- The installed Samsung USB init file starts `hdcd` only. ConfigFS gadget
  setup, controller binding and host connectivity have not been established.
- The board's fstab is an uninstalled reference. Its Android recovery syntax
  and the OpenHarmony system/userdata mount topology require translation.
- The inherited composer gate waits for `android.composer.ready=1`. A Samsung
  Android HAL bootstrap does not yet set that condition. This gate cannot be
  used as evidence of a working software-rendered screen.
- Samsung display configuration installs with DPI 0 (platform default) until
  active panel dimensions and density are verified. This is configuration,
  not an implemented display HDI.
- Audio, codec, HDF host and performance configurations are inherited from
  Oniro and need hardware review before enabling their services on Samsung.

Static verification can resolve staged GN labels and JSON identities. A full
GN/build run is still required to verify external dependencies and toolchain
compatibility; a device boot is required to verify runtime behavior.
