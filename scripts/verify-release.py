#!/usr/bin/env python3
"""Read-only checks for the same release bundle on a local Mac and in CI."""

import argparse
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys


BUNDLE_ID = "io.github.snowdrit.Cornice"
REQUIRED_FILES = {
    "Contents/Info.plist",
    "Contents/MacOS/Cornice",
    "Contents/Resources/Assets.car",
    "Contents/Resources/AppIcon.icns",
    "Contents/_CodeSignature/CodeResources",
}
OPTIONAL_FILES = {"Contents/PkgInfo"}
ALLOWED_DIRECTORIES = {
    "Contents", "Contents/MacOS", "Contents/Resources", "Contents/_CodeSignature",
}
FORBIDDEN_MARKERS = (
    b"CORNICE_RUN_", b"CORNICE_SHOW_SETTINGS", b"CORNICE_SETTINGS_TAB",
    b"CORNICE_DEBUG_VISIBILITY", b"/Users/", b"/home/",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def command(*arguments):
    result = subprocess.run(arguments, capture_output=True, check=False, timeout=60)
    require(result.returncode == 0,
            f"{Path(arguments[0]).name} failed: {result.stderr.decode(errors='replace').strip()}")
    return result


def version_tuple(value):
    require(isinstance(value, str) and re.fullmatch(r"\d+\.\d+(?:\.\d+)?", value),
            f"Invalid version: {value!r}")
    numbers = tuple(map(int, value.split(".")))
    return numbers + (0,) * (3 - len(numbers))


def project_versions(project):
    source = project.read_text()
    values = []
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        matches = {value.strip().strip('"') for value in
                   re.findall(rf"\b{key}\s*=\s*([^;]+);", source)}
        require(len(matches) == 1, f"Project must have one consistent {key}")
        values.append(matches.pop())
    return values


def verify_files(app):
    require(app.is_dir() and not app.is_symlink(), "Expected a real application directory")
    found = set()
    for current, directories, files in os.walk(app, followlinks=False):
        for name in directories + files:
            path = Path(current) / name
            relative = path.relative_to(app).as_posix()
            require(not path.is_symlink(), f"Unexpected bundle symlink: {relative}")
            if path.is_dir():
                require(relative in ALLOWED_DIRECTORIES, f"Unexpected bundle directory: {relative}")
            else:
                require(path.is_file(), f"Unexpected bundle entry: {relative}")
                found.add(relative)
    require(REQUIRED_FILES <= found, f"Missing bundle files: {sorted(REQUIRED_FILES - found)}")
    require(found <= REQUIRED_FILES | OPTIONAL_FILES,
            f"Unexpected bundle files: {sorted(found - REQUIRED_FILES - OPTIONAL_FILES)}")


def verify_macho(data, sdk, minimum_os):
    require(len(data) >= 32, "Executable is too short")
    magic, cpu, subtype, file_type, count, command_bytes, _, _ = struct.unpack_from("<8I", data)
    require(magic == 0xFEEDFACF and cpu == 0x0100000C
            and subtype & 0xFFFFFF == 0 and file_type == 2,
            "Expected a thin arm64 Mach-O executable")
    end = 32 + command_bytes
    require(end <= len(data), "Truncated Mach-O load commands")
    offset = 32
    versions = []
    for _ in range(count):
        require(offset + 8 <= end, "Invalid Mach-O load command")
        kind, size = struct.unpack_from("<2I", data, offset)
        require(size >= 8 and offset + size <= end, "Invalid Mach-O load command size")
        if kind == 0x32:  # LC_BUILD_VERSION
            require(size >= 24, "Invalid LC_BUILD_VERSION")
            platform, target, linked_sdk = struct.unpack_from("<3I", data, offset + 8)
            def unpack(number):
                return number >> 16, (number >> 8) & 255, number & 255
            versions.append((platform, unpack(target), unpack(linked_sdk)))
        offset += size
    require(offset == end, "Inconsistent Mach-O load command count")
    require(versions == [(1, version_tuple(minimum_os), version_tuple(sdk))],
            f"Unexpected Mach-O platform/minimum OS/SDK: {versions}")


def verify(args):
    app = args.app.absolute()
    verify_files(app)
    expected_version, expected_build = project_versions(args.project)
    require(re.fullmatch(r"\d+\.\d+\.\d+", expected_version), "Project version must be X.Y.Z")
    require(re.fullmatch(r"\d+", expected_build), "Project build number must be numeric")
    if args.tag:
        require(args.tag == f"v{expected_version}", "Release tag does not match the project version")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    require(isinstance(info, dict), "Info.plist must be a dictionary")
    expected = {
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleExecutable": "Cornice",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": expected_version,
        "CFBundleVersion": expected_build,
    }
    for key, value in expected.items():
        require(info.get(key) == value, f"Unexpected {key}: {info.get(key)!r}")
    require(info.get("LSUIElement") is True, "LSUIElement must be true")
    require(version_tuple(info.get("LSMinimumSystemVersion")) == version_tuple(args.minimum_os),
            "Unexpected minimum macOS in Info.plist")
    require("LSEnvironment" not in info, "QA/environment injection is forbidden in Info.plist")
    encoded_info = plistlib.dumps(info)
    executable = app / "Contents/MacOS/Cornice"
    require(os.access(executable, os.X_OK), "Application executable is not executable")
    binary = executable.read_bytes()
    for marker in FORBIDDEN_MARKERS:
        require(marker not in binary and marker not in encoded_info,
                f"Forbidden release marker: {marker.decode()}")
    verify_macho(binary, args.sdk, args.minimum_os)
    command("/usr/bin/codesign", "--verify", "--deep", "--strict", str(app))
    signature = command("/usr/bin/codesign", "-d", "--verbose=2", str(app))
    require(f"Identifier={BUNDLE_ID}" in signature.stderr.decode(errors="replace").splitlines(),
            "Code-signing identifier does not match the bundle")
    raw_entitlements = command("/usr/bin/codesign", "-d", "--entitlements", "-", str(app)).stdout
    entitlements = plistlib.loads(raw_entitlements) if raw_entitlements.strip() else {}
    require(isinstance(entitlements, dict), "Entitlements must be a dictionary")
    for key in ("com.apple.security.app-sandbox", "com.apple.security.get-task-allow",
                "get-task-allow", "com.apple.security.cs.disable-library-validation",
                "com.apple.security.cs.allow-dyld-environment-variables"):
        require(not entitlements.get(key), f"Forbidden release entitlement: {key}")
    print(f"PASS: Cornice {expected_version} ({expected_build}), arm64, "
          f"macOS {args.minimum_os}+, SDK {args.sdk}; bundle and signature verified")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--project", type=Path,
                        default=Path(__file__).resolve().parents[1] / "Cornice.xcodeproj/project.pbxproj")
    parser.add_argument("--tag", default="")
    parser.add_argument("--sdk", default="26.5")
    parser.add_argument("--minimum-os", default="26.0")
    args = parser.parse_args()
    try:
        verify(args)
    except (ValueError, OSError, plistlib.InvalidFileException, subprocess.TimeoutExpired) as error:
        print(f"Release verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
