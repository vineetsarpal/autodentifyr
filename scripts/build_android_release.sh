#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build_android_release.sh [split|universal|appbundle] [Flutter build arguments...]

  split       Build release APKs for armeabi-v7a, arm64-v8a and x86_64 (default).
  universal   Build one release APK containing all three architectures.
  appbundle   Build a release Android App Bundle for Google Play.

Version, flavor, Dart define and other Flutter build arguments are forwarded.
ABI selection, APK splitting and non-release modes are reserved by this script.
Relative argument paths are resolved from the repository root.
Release signing uses the existing android/key.properties configuration.
This script builds artifacts; it does not install or publish them.

Examples:
  scripts/build_android_release.sh
  scripts/build_android_release.sh appbundle --build-name=1.0.4 --build-number=9
  scripts/build_android_release.sh universal --no-pub
USAGE
}

release_mode=split
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  split|universal|appbundle) release_mode=$1; shift ;;
  '') ;;
  -*) ;;
  *) usage >&2; exit 2 ;;
esac
if [[ "${1:-}" == -- ]]; then
  shift
fi

for argument in "$@"; do
  case "$argument" in
    --target-platform|--target-platform=*|--split-per-abi|--no-split-per-abi|--debug|--profile)
      printf 'Reserved release option: %s\n' "$argument" >&2
      printf 'Use split, universal or appbundle; every mode retains all supported architectures.\n' >&2
      exit 2
      ;;
  esac
done

release_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$release_root"
target_platforms=android-arm,android-arm64,android-x64
case "$release_mode" in
  split)
    build_arguments=(build apk --release --split-per-abi --target-platform="$target_platforms")
    ;;
  universal)
    build_arguments=(build apk --release --target-platform="$target_platforms")
    ;;
  appbundle)
    build_arguments=(build appbundle --release --target-platform="$target_platforms")
    ;;
esac
exec flutter "${build_arguments[@]}" "$@"
