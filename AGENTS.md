# Workspace instructions

Read `CRAVE-RULES.md` before any Crave operation and follow its restrictions.

## Explicit user rule: NO BASE64

Never use base64 to encode or transfer commands, scripts, source files,
archives, or build payloads in this project. Use normal, readable shell
commands and directly inspectable source files. Crave build scripts must be
publicly available as readable source before submission.

Do not replace base64 with another encoding, encryption, or obfuscation scheme.
If ordinary file transfer fails, fix it or report the blocker; do not embed an
encoded payload. Existing encoded artifacts and saved submission commands are
historical only: never execute or resubmit them.
