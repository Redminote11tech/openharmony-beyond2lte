# Public userspace build recipe

All three repository scripts are directly readable source. Read the workspace
rules, confirm no other queue job is active, and run the existing public
checkout's pipeline only on an allocated Crave build node:

```sh
CRAVE_BUILD_NODE=1 bash /path/to/public-checkout/crave-beyond2lte-pipeline.sh
```

Source setup uses the public Oniro manifest and applies its shared patches.
An existing patch-state file is accepted only after complete coverage and Git
ancestry checks. The follow-up selects `BEYOND2LTE_USERSPACE_ONLY=1`, installs
this checkout's Samsung source overlay into fresh destinations, then builds
one `beyond2lte` userspace target. No kernel binary, source reconstruction,
encoded payload or boot-image packaging is involved.

Retain the same workspace path, sources and `out` directory. The script records
logs, resolved source revisions and patch state. Failure is propagated with
an exit marker; GN or compiler success is never assumed before the build.
