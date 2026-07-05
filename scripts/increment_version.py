#!/usr/bin/env python3
"""
Increment Flutter project version safely across all versioned files.

- Prompts for a new version (or use --new-version).
- Verifies the new version is greater than the one in pubspec.yaml.
- Updates `version:` in pubspec.yaml (e.g. 1.8.4+25).
- Increments the build number (+N suffix) by 1.
- Updates AppVersion in windows/installer/paperless_ngx_uploader.iss.
- Updates Version in linux/net.gmartin.paperlessngx_uploader.desktop.
- Creates .bak backups before overwriting each file.

Usage:
  python scripts/increment_version.py [--path PATH_TO_PROJECT_ROOT] [--new-version X.Y.Z]

This script is written in English and designed to work with Flutter projects
that follow the default structure (pubspec.yaml in project root).
"""

from __future__ import annotations
import argparse
import os
import re
import shutil
import sys
from typing import List, Optional, Tuple


def parse_version(version: str) -> List[int]:
    """Parse a semantic-like version string into a list of integers.

    Non-numeric or extra components are ignored. Missing components are treated as 0.
    Examples: "1.2.3" -> [1,2,3], "1.4" -> [1,4,0], "2" -> [2,0,0]
    """
    parts = re.split(r"[.+-]", version.strip())
    nums: List[int] = []
    for p in parts:
        if p.isdigit():
            nums.append(int(p))
        else:
            # try to extract leading digits
            m = re.match(r"(\d+)", p)
            if m:
                nums.append(int(m.group(1)))
    while len(nums) < 3:
        nums.append(0)
    return nums[:3]


def is_newer_version(new: str, current: str) -> bool:
    return parse_version(new) > parse_version(current)


def read_pubspec_version(path: str) -> Tuple[str, int, str]:
    """Returns (version_name, build_number, full_text).

    Parses the Flutter pubspec version format ``X.Y.Z+N``:
    - version_name: the part before ``+`` (e.g. ``1.8.4``)
    - build_number: the integer after ``+`` (``flutter.versionCode``); 0 if absent
    """
    pubspec_path = os.path.join(path, "pubspec.yaml")
    if not os.path.exists(pubspec_path):
        raise FileNotFoundError(f"pubspec.yaml not found at {pubspec_path}")
    text = open(pubspec_path, "r", encoding="utf-8").read()
    m = re.search(r"^version:\s*(\S+)", text, flags=re.MULTILINE)
    if not m:
        raise ValueError("Could not find a 'version:' line in pubspec.yaml")
    full_version = m.group(1)
    if '+' in full_version:
        name_part, build_part = full_version.split('+', 1)
        build_number = int(build_part) if build_part.isdigit() else 0
    else:
        name_part = full_version
        build_number = 0
    return name_part, build_number, text


def write_pubspec_version(path: str, new_version_name: str, new_build_number: int, original_text: str) -> None:
    pubspec_path = os.path.join(path, "pubspec.yaml")
    bak_path = pubspec_path + ".bak"
    shutil.copyfile(pubspec_path, bak_path)
    full_version = f"{new_version_name}+{new_build_number}"
    # Use concatenation instead of backreference in a single replacement string so
    # we don't accidentally create sequences like "\\10" which are treated as
    # group 10 by the regex engine when the new version starts with a digit.
    new_text = re.sub(r"(^version:\s*)(\S+)", lambda m: m.group(1) + full_version, original_text, flags=re.MULTILINE)
    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(new_text)


def update_iss_version(path: str, new_version: str) -> bool:
    """If present, update windows/installer/paperless_ngx_uploader.iss AppVersion to new_version.

    Creates a .bak backup before writing. Returns True if file existed and was
    modified, False if file not present.
    """
    iss_path = os.path.join(path, 'windows', 'installer', 'paperless_ngx_uploader.iss')
    if not os.path.exists(iss_path):
        return False
    text = open(iss_path, 'r', encoding='utf-8').read()
    bak_path = iss_path + '.bak'
    shutil.copyfile(iss_path, bak_path)

    # Replace existing AppVersion line if present, otherwise insert under [Setup]
    if re.search(r"(?m)^(AppVersion\s*=\s*).*$", text):
        new_text = re.sub(r"(?m)^(AppVersion\s*=\s*).*$", lambda m: m.group(1) + new_version, text)
    else:
        if re.search(r"(?m)^\[Setup\]\s*$", text):
            new_text = re.sub(r"(?m)^(\[Setup\]\s*$)", lambda m: m.group(1) + '\nAppVersion=' + new_version, text, count=1)
        else:
            new_text = text + '\nAppVersion=' + new_version + '\n'

    with open(iss_path, 'w', encoding='utf-8') as f:
        f.write(new_text)

    return True


def update_desktop_version(path: str, new_version: str) -> bool:
    """If present, update linux/net.gmartin.paperlessngx_uploader.desktop Version to new_version.

    Creates a .bak backup before writing. Returns True if file existed and was
    modified, False if file not present.
    """
    desktop_path = os.path.join(path, 'linux', 'net.gmartin.paperlessngx_uploader.desktop')
    if not os.path.exists(desktop_path):
        return False
    text = open(desktop_path, 'r', encoding='utf-8').read()
    bak_path = desktop_path + '.bak'
    shutil.copyfile(desktop_path, bak_path)

    # Replace existing Version= line if present, otherwise insert after [Desktop Entry]
    if re.search(r"(?m)^(Version\s*=).*$", text):
        new_text = re.sub(r"(?m)^(Version\s*=).*$", lambda m: m.group(1) + new_version, text)
    else:
        if re.search(r"(?m)^\[Desktop Entry\]\s*$", text):
            new_text = re.sub(r"(?m)^(\[Desktop Entry\]\s*$)", lambda m: m.group(1) + '\nVersion=' + new_version, text, count=1)
        else:
            new_text = text + '\nVersion=' + new_version + '\n'

    with open(desktop_path, 'w', encoding='utf-8') as f:
        f.write(new_text)

    return True


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Increment Flutter project version across all versioned files"
    )
    parser.add_argument("--path", "-p", default=".", help="Path to project root (default: current directory)")
    parser.add_argument("--new-version", "-n", help="New version to set (e.g. 1.8.5). If omitted, you'll be prompted.")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.path)
    try:
        current_version_name, current_build_number, pubspec_text = read_pubspec_version(root)
    except Exception as e:
        print(f"Error reading pubspec.yaml: {e}")
        return 2
    current_version = (
        f"{current_version_name}+{current_build_number}"
        if current_build_number
        else current_version_name
    )

    if args.new_version:
        new_version = args.new_version.strip()
    else:
        new_version = input(f"Current version is {current_version}. Enter new version name (e.g. 1.8.5): ").strip()

    if not re.match(r"^\d+(\.\d+){0,2}([.-].*)?$", new_version):
        print("The new version doesn't look like a valid numeric version (e.g. 1.8.5). Aborting.")
        return 3

    if not is_newer_version(new_version, current_version):
        print(f"Provided version {new_version} is not greater than current version {current_version}. Aborting.")
        return 4

    new_build_number = current_build_number + 1

    # ── 1. Update pubspec.yaml ──────────────────────────────────────────────
    try:
        write_pubspec_version(root, new_version, new_build_number, pubspec_text)
    except Exception as e:
        print(f"Failed to update pubspec.yaml: {e}")
        return 5

    new_full_version = f"{new_version}+{new_build_number}"
    print("Update complete:")
    print(f" - pubspec.yaml: {current_version} -> {new_full_version} (backup at pubspec.yaml.bak)")
    print(f"   versionCode (build number): {current_build_number} -> {new_build_number}")
    print(f"   ABI split versionCodes → armeabi-v7a={new_build_number * 10 + 1}, arm64-v8a={new_build_number * 10 + 2}, x86_64={new_build_number * 10 + 3}")

    # ── 2. Update Inno Setup script ─────────────────────────────────────────
    try:
        modified_iss = update_iss_version(root, new_version)
        if modified_iss:
            print(f" - windows/installer/paperless_ngx_uploader.iss: AppVersion updated to {new_version}")
        else:
            print(" - windows/installer/paperless_ngx_uploader.iss: not found, skipping")
    except Exception as e:
        print(f" - Warning: failed to update .iss file: {e}")

    # ── 3. Update Linux .desktop file ───────────────────────────────────────
    try:
        modified_desktop = update_desktop_version(root, new_version)
        if modified_desktop:
            print(f" - linux/net.gmartin.paperlessngx_uploader.desktop: Version updated to {new_version}")
        else:
            print(" - linux/net.gmartin.paperlessngx_uploader.desktop: not found, skipping")
    except Exception as e:
        print(f" - Warning: failed to update .desktop file: {e}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
