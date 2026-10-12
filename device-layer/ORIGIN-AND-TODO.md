# Source origin and remaining port work

The Samsung board/vendor trees were adapted from Eclipse Oniro's public
`hybris_generic` on `OpenHarmony-6.1-LTS`. Existing copyright/license notices
are preserved. The selected board group installs Samsung configuration only;
MediaTek launcher and audio implementations are excluded from this source tree.

The generic SoC remains the published Oniro adaptation. Its Android HAL and
hardware assumptions require Samsung review; successful userspace compilation
would not establish native hardware support. Software framebuffer graphics,
Samsung HAL bootstrap, installation mounts and firmware packaging remain
unfinished. The optional kernel helper validates/stages a separately supplied
raw ARM64 Image; the queued public pipeline does not invoke kernel packaging.

Kernel source patches and the minimal kernel HDF profile are separately
attributed in the repository README. Generated/binary patch hunks are omitted
and listed in SOURCE-FILTERS.json. Do not use inherited other-device flashing
helpers on a Samsung device.
