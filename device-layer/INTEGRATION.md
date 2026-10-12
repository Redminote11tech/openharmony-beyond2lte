# Samsung source integration

Prepare the complete public Oniro OpenHarmony-6.1-LTS manifest and shared
patch series. The dependency set includes the Oniro board, vendor, shared
hybris SoC, libhybris and Halium Android headers. A plain OpenHarmony release
tarball is insufficient for the upstream Git patch helper.

From this public checkout, validate first and apply only fresh destinations:

```sh
python3 tools/integrate_device_layer.py /path/to/prepared/ohos
python3 tools/integrate_device_layer.py /path/to/prepared/ohos --apply
```

The copied Samsung board/product use `device_beyond2lte` and
`product_beyond2lte`. The SoC stays `oniro/hybris_generic`. Shared HAP,
wallpaper and boot-picture sources remain explicit public upstream references.
Build options are the matching Oniro phone reference's
`bash ./build.sh --product-name beyond2lte --ccache`.

These are static source connections, not verified Samsung HDIs. Remaining
work includes rootfs/mount installation, Samsung Android HAL bootstrap and
composer readiness, display/input integration and hardware validation of
USB, audio, modem, sensors and camera. The inherited composer gate does not
implement an independent software framebuffer display path.

See the repository README and public queued scripts for exact build scope.
