# Samsung configuration scope

`product_etc_conf` installs only `hardware_beyond2lte.para`,
`product_beyond2lte.para` and the narrowed Samsung ueventd overlay. The Volla
X23/Ansuz files are retained as references but are not dependencies and are not
installed by this group. Device model is fixed to the staged SM-G975F/Exynos
product; runtime hardware revision detection is not implemented.

HDC TCP/developer mode are bring-up settings. USB remains disabled in parameters
until the native helper confirms configfs/FunctionFS setup and a unique
registered UDC. The init trigger then enables HDC USB; the helper binds only
after hdcd publishes endpoint readiness. Enumeration remains untested on phone.
See `init/USB-BRINGUP.md`. No Volla seccomp/GWP-ASan/rendering
workarounds are enabled by these files.

The ueventd overlay uses Linux framebuffer, Mali, ION, input and OH access-token
nodes consistent with the local kernel configuration. Kernel support does not
prove node availability, OpenHarmony account ownership, a working display HDI,
or runtime hardware-service access. Verify those on first boot. MediaTek DMA
heaps, audio DSP and sensorhub entries have been removed from the active overlay.
