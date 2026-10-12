#!/usr/bin/env python3
"""Install the Samsung overlay into a prepared Oniro 6.1 tree; never sync/build."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
OVERLAY = PROJECT / "device-layer"
REGISTRATIONS = {
    "device_beyond2lte": "device/board/samsung/beyond2lte",
    "product_beyond2lte": "vendor/samsung/beyond2lte",
}
REQUIRED = [
    "build.sh", "build/ohos.gni", "build/subsystem_config.json",
    "device/soc/oniro/hybris_generic/bundle.json",
    "third_party/libhybris/libhybris_args.gni",
    "third_party/android-headers",
    "vendor/oniro/oniro-haps/oniro_haps.gni",
    "vendor/oniro/wallpaper/BUILD.gn",
    "device/board/oniro/system_patch/patches",
    "device/board/oniro/system_patch/.patch_state",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--apply", action="store_true", help="copy overlay and register subsystems")
    args = parser.parse_args()
    root = args.source_root.resolve()
    missing = [name for name in REQUIRED if not (root / name).exists()]
    if missing:
        parser.exit(1, "Source tree is not prepared; missing:\n  " + "\n  ".join(missing) + "\nSee device-layer/INTEGRATION.md.\n")
    if not (root / "device/board/oniro/system_patch/.patch_state").stat().st_size:
        parser.exit(1, "Oniro patch-state file is empty; upstream patch preparation is incomplete.\n")
    patch_dir = root / "device/board/oniro/system_patch/patches"
    expected = {str(p.parent.relative_to(patch_dir)) for p in patch_dir.rglob("*.patch")}
    state_lines = (root / "device/board/oniro/system_patch/.patch_state").read_text().splitlines()
    applied = set()
    post_revisions = {}
    for line in state_lines:
        fields = line.split("\t")
        if len(fields) != 3 or any(len(sha) != 40 or any(c not in "0123456789abcdef" for c in sha) for sha in fields[1:]):
            parser.exit(1, "Malformed upstream patch-state row.\n")
        if fields[0] in applied:
            parser.exit(1, "Duplicate upstream patch-state row.\n")
        applied.add(fields[0])
        post_revisions[fields[0]] = fields[2]
    if not expected or expected != applied:
        parser.exit(1, "Upstream patch-state does not cover the complete shared patch series.\n")
    for relative, sha in post_revisions.items():
        result = subprocess.run(["git", "-C", str(root / relative), "merge-base",
                                 "--is-ancestor", sha, "HEAD"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode:
            parser.exit(1, f"Recorded post-patch revision is absent from {relative}; review source state.\n")
    registry_path = root / "build/subsystem_config.json"
    registry = json.loads(registry_path.read_text())
    if registry.get("oniro_soc_products", {}).get("path") != "device/soc/oniro":
        parser.exit(1, "Missing Oniro SoC subsystem registration; prepare matching upstream patches first.\n")
    for name, relative in REGISTRATIONS.items():
        source, target = OVERLAY / relative, root / relative
        if not source.is_dir():
            parser.exit(1, f"Overlay missing: {source}\n")
        entry = {"path": relative, "name": name}
        if name in registry and registry[name] != entry:
            parser.exit(1, f"Conflicting subsystem registration: {name}\n")
        if args.apply and target.exists():
            parser.exit(1, f"Destination already exists: {target}; review existing overlay before updating.\n")
    for name, relative in REGISTRATIONS.items():
        print(f"{name}: {OVERLAY / relative} -> {root / relative}")
    if not args.apply:
        print("Preflight passed. Add --apply to install. No build was run.")
        return
    # Both destinations were checked before writing. Shared Oniro sources are untouched.
    for name, relative in REGISTRATIONS.items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(OVERLAY / relative, target,
                        ignore=shutil.ignore_patterns(".git", "_mtk_reference", "_reference_x23", "__pycache__"))
        registry[name] = {"path": relative, "name": name}
    registry_path.write_text(json.dumps(registry, indent=2) + "\n")
    print("Overlay installed. Product/GN generation and runtime are still unverified.")


if __name__ == "__main__":
    main()
