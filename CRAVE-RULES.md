# Crave rules for this public build recipe

Read these before any Crave operation. Use one account, only public FOSS
repositories, the existing workspace identity, one active queued job and one
product target on the default free platform. No paid-platform override is used. Never sync or build in devspace/SSH. Source setup and builds
must run through `crave run` on an allocated build node.

Do not delete Crave clones or pre-synced sources with recursive removal, wipe
`out` to retry, churn workspaces or change the build container without the
required approval. Use the supported Crave lifecycle tools when cleanup is
actually needed. Check current queue state and maintenance announcements
before submission. Preserve sources and logs on failures.

Commands and scripts must be directly readable public source before queue
submission. No encoding, encrypted payload, hidden source reconstruction or
obfuscation is permitted. If ordinary public Git/file transfer fails, fix it
or report the blocker. Historical encoded artifacts are never submitted.

The `CRAVE_BUILD_NODE=1` guard is explicit operator intent, not automatic
proof of the execution environment. Never set it to run build scripts locally
or inside devspace/SSH.

Public source references:

- https://github.com/accupara/crave
- https://crave.io/open-source
- https://fosson.top/crave/rules.html
