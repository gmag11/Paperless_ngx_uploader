#!/usr/bin/env python3
"""
Increment Flutter project version safely.

- Prompts for a new version (or use --new-version).
- Verifies the new version is greater than the one in pubspec.yaml.
- Updates `version:` in pubspec.yaml.
- Increments `versionCode` by 1 in `android/app/build.gradle.kts`.
- Creates .bak backups before overwriting files.

Usage:
  python scripts/increment_version.py [--path PATH_TO_PROJECT_ROOT] [--new-version X.Y.Z]

This script is written in English and designed to work with Flutter projects
that follow the default structure (pubspec.yaml in project root and
android/app/build.gradle.kts present).
"""

from __future__ import annotations
import argparse
import os
import re
import shutil
import sys
from typing import List, Tuple


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


def read_pubspec_version(path: str) -> Tuple[str, str]:
    pubspec_path = os.path.join(path, "pubspec.yaml")
    if not os.path.exists(pubspec_path):
        raise FileNotFoundError(f"pubspec.yaml not found at {pubspec_path}")
    text = open(pubspec_path, "r", encoding="utf-8").read()
    m = re.search(r"^version:\s*(\S+)", text, flags=re.MULTILINE)
    if not m:
        raise ValueError("Could not find a 'version:' line in pubspec.yaml")
    return m.group(1), text


def write_pubspec_version(path: str, new_version: str, original_text: str) -> None:
    pubspec_path = os.path.join(path, "pubspec.yaml")
    bak_path = pubspec_path + ".bak"
    shutil.copyfile(pubspec_path, bak_path)
    # Use concatenation instead of backreference in a single replacement string so
    # we don't accidentally create sequences like "\\10" which are treated as
    # group 10 by the regex engine when the new version starts with a digit.
    new_text = re.sub(r"(^version:\s*)(\S+)", lambda m: m.group(1) + new_version, original_text, flags=re.MULTILINE)
    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(new_text)


def increment_version_code_in_gradle(path: str) -> Tuple[int, str]:
    gradle_path = os.path.join(path, "android", "app", "build.gradle.kts")
    if not os.path.exists(gradle_path):
        raise FileNotFoundError(f"{gradle_path} not found")
    text = open(gradle_path, "r", encoding="utf-8").read()
    m = re.search(r"versionCode\s*=\s*(\d+)", text)
    if not m:
        raise ValueError("Could not find a 'versionCode = <number>' assignment in build.gradle.kts")
    current_code = int(m.group(1))
    new_code = current_code + 1
    bak_path = gradle_path + ".bak"
    shutil.copyfile(gradle_path, bak_path)
    # Use a lambda replacement to avoid accidental group-number collisions
    # when the numeric replacement starts with digits (e.g. "0...").
    new_text = re.sub(r"(versionCode\s*=\s*)(\d+)", lambda m: m.group(1) + str(new_code), text, count=1)
    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(new_text)
    return current_code, new_code


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Increment Flutter project version (pubspec + android versionCode)")
    parser.add_argument("--path", "-p", default=".", help="Path to project root (default: current directory)")
    parser.add_argument("--new-version", "-n", help="New version to set (e.g. 1.2.3). If omitted, you'll be prompted.")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.path)
    try:
        current_version, pubspec_text = read_pubspec_version(root)
    except Exception as e:
        print(f"Error reading pubspec.yaml: {e}")
        return 2

    if args.new_version:
        new_version = args.new_version.strip()
    else:
        new_version = input(f"Current version in pubspec.yaml is {current_version}. Enter the new version: ").strip()

    if not re.match(r"^\d+(\.\d+){0,2}([.-].*)?$", new_version):
        print("The new version doesn't look like a valid numeric version (e.g. 1.2.3). Aborting.")
        return 3

    if not is_newer_version(new_version, current_version):
        print(f"Provided version {new_version} is not greater than current version {current_version}. Aborting.")
        return 4

    # Update pubspec.yaml
    try:
        write_pubspec_version(root, new_version, pubspec_text)
    except Exception as e:
        print(f"Failed to update pubspec.yaml: {e}")
        return 5

    # Update android versionCode (if file present)
    gradle_path = os.path.join(root, "android", "app", "build.gradle.kts")
    try:
        old_code, new_code = increment_version_code_in_gradle(root)
    except FileNotFoundError:
        print(f"Warning: {gradle_path} not found. pubspec updated but versionCode not modified.")
        print("Done.")
        return 0
    except Exception as e:
        print(f"Failed to update build.gradle.kts: {e}")
        return 6

    print("Update complete:")
    print(f" - pubspec.yaml: {current_version} -> {new_version} (backup at pubspec.yaml.bak)")
    print(f" - android/app/build.gradle.kts: versionCode {old_code} -> {new_code} (backup at android/app/build.gradle.kts.bak)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
