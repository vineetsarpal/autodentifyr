# Direct Android APK distribution

Use per-ABI APKs for direct downloads. Each device receives one APK containing its
native architecture. Keep every artifact available to retain the supported device
range. Google Play releases use an App Bundle; follow the
[Play release runbook](google-play-release-runbook.md) for validation and rollout.

## Build signed artifacts

Complete source validation and prepare the same local Firebase, model, and
`android/key.properties` signing inputs listed in the Play runbook. Then run:

```bash
scripts/build_android_release.sh
```

The default is equivalent to:

```bash
flutter build apk --release --split-per-abi --target-platform=android-arm,android-arm64,android-x64
```

The script works from any current directory, resolves relative build arguments
from the repository root, and forwards arguments such as `--build-name`,
`--build-number`, `--flavor`, `--dart-define`, and `--no-pub`. Architecture,
splitting, and non-release mode flags are reserved to keep all supported ABIs.
Existing Gradle release signing, shrinking, model assets, and minimum Android
version apply to every output.

Default output names are:

| Device ABI | Release APK |
| --- | --- |
| `armeabi-v7a` | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` |
| `arm64-v8a` | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| `x86_64` | `build/app/outputs/flutter-apk/app-x86_64-release.apk` |

Flavored builds may use different filenames; use the artifacts reported by
Flutter. Record the version, commit, file size, SHA-256 checksum, and signing
certificate for each APK. Keep any separately generated debug symbols for crash
symbolication.

Record the actual packaged `versionCode`, not only the build number in
`pubspec.yaml`. Inspect each APK with Android SDK Build Tools `aapt`:

```bash
aapt dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | rg '^package:'
```

Flutter adds ABI-specific version-code offsets to split APKs. For example, the
validated build number `10` produced universal code `10` and split codes `1010`
(ARM32), `2010` (ARM64), and `4010` (x86-64). Switching from a split APK to a
universal APK or bundle-based distribution can therefore be treated as a
downgrade even when the base build number increases. Retain the distribution
channel or choose a release code that packages above the installed code, with
compatible signing. Verify the final artifact rather than assuming the offsets;
do not uninstall or clear assessment data to bypass the update checks.

## Select and install one APK

Query the device's supported ABIs:

```bash
adb -s DEVICE_ID shell getprop ro.product.cpu.abilist
```

Choose the first ABI in that list represented in the table. For example, select
the ARM64 APK when the list starts with `arm64-v8a`. Each file is a complete APK;
it can be installed individually rather than as an `install-multiple` set.

Verify the artifact using Android SDK Build Tools `apksigner`:

```bash
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
shasum -a 256 build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Before updating an installed copy, confirm that its signing certificate matches
the new artifact and its version code permits the update. Play-installed apps
may use the Play app-signing certificate rather than the local upload
certificate. Install the compatible APK with:

```bash
adb -s DEVICE_ID install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

If Android reports a signing mismatch, stop and resolve signing compatibility.
Uninstalling removes device-local assessment records. The build script performs
no installation or uninstall fallback.

## Universal APK and Play App Bundle

For a distribution channel that requires one APK for every architecture:

```bash
scripts/build_android_release.sh universal
```

This produces `build/app/outputs/flutter-apk/app-release.apk` with all three
architectures. Its larger download includes native libraries for other device
architectures. Per-ABI downloads reduce direct-distribution download size while
retaining each supported architecture as a separate artifact.

For Google Play:

```bash
scripts/build_android_release.sh appbundle
```

This produces `build/app/outputs/bundle/release/app-release.aab`. Play generates
the device-specific packages; the uploaded AAB's size is not the delivered
download size. Keep APK and AAB distribution evidence separate when comparing
artifact sizes.
