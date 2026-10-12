# Active Samsung kernel HDF baseline

`hdf.hcs` includes only `device_info/device_info.hcs` and labels the module
`samsung,exynos9820`. Its active nodes are KEVENT, the GPIO manager plus
Linux GPIO adapter, and the I2C manager plus Linux I2C adapter.

GPIO/I2C adapters enumerate already registered Linux controllers. This
configuration does not establish Samsung peripheral I/O or implement a
Samsung display/input/audio HDI. All other sibling configurations are inactive
references. The user-space `uhdf/` configuration is separate.

This staged configuration is synchronized with the local kernel build input
under `kernel-config/beyond2lte/khdf`. Adopting these source files requires
a separate kernel rebuild and hardware validation. No compiled configuration
or kernel binary is distributed here.
