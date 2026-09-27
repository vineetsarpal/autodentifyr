# Google Play release runbook

Use this runbook for every AutoDentifyr Android release. Google Play releases
use a signed Android App Bundle (`.aab`), not an APK.

## One-time setup

- [ ] Confirm `com.vineetsarpal.autodentifyr` is the permanent Play package
      name. A published app cannot change its package name.
- [ ] Complete Play Console developer identity and package registration.
- [ ] Enrol the app in Play App Signing.
- [ ] Back up the upload keystore and its passwords outside the repository.
- [ ] Keep `android/key.properties`, the keystore, Firebase configuration, and
      ML model binaries out of Git.
- [ ] Add the Play app-signing SHA-1 and SHA-256 fingerprints to the Android app
      in Firebase, then verify Google Sign-In from a Play-installed build.
- [ ] Publish a privacy policy and account-deletion request page.
- [ ] Complete Play Console's App content, Data safety, content rating, target
      audience, app access, and account-deletion declarations.

Official references:

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Play App Signing](https://developer.android.com/studio/publish/app-signing)
- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)

## 1. Prepare the release

Start from the intended release commit with no unexplained local changes:

```bash
git status --short
```

Update `version` in `pubspec.yaml`. Increase both values:

```yaml
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

For example, after `1.0.3+8`, use `1.0.4+9`. Google Play never permits reuse
of a previously uploaded build number, even if that release was discarded.

Confirm these ignored local release inputs exist:

```text
lib/firebase_options.dart
android/app/google-services.json
android/key.properties
android/app/src/main/assets/best.tflite
```

Do not substitute the CI placeholder Firebase project in a production bundle.

## 2. Validate the source

Run the same quality gates used by CI:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Resolve every failure before building. Package-update notices and explicitly
understood nonfatal warnings do not by themselves fail the release.

## 3. Build and verify the bundle

Build the signed release bundle:

```bash
flutter build appbundle --release
```

The output is:

```text
build/app/outputs/bundle/release/app-release.aab
```

Verify the bundle signature and record its checksum:

```bash
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
shasum -a 256 build/app/outputs/bundle/release/app-release.aab
```

`jar verified` confirms that the bundle is signed. A self-signed certificate
warning is expected for an upload key; Google Play validates the registered
upload certificate and applies the Play app-signing key for distribution.

## 4. Upload to Internal testing

In Play Console:

1. Open **Test and release > Testing > Internal testing**.
2. Select the **Releases** tab.
3. Click **Create new release**.
4. Upload `build/app/outputs/bundle/release/app-release.aab`.
5. Confirm the detected version name and build number match `pubspec.yaml`.
6. Enter concise user-facing release notes.
7. Click **Next** or **Review release**.
8. Resolve every error and review each warning.
9. Click **Start rollout to Internal testing** and confirm.

Example release notes:

```text
Improved vehicle component selection and assessment workflow.
Updated the vehicle findings map.
Improved assessment reporting and stability.
```

Do not select **Production** for an untested bundle.

## 5. Give testers access

1. Open the Internal testing **Testers** tab.
2. Add the approved email list or Google Group.
3. Save the tester configuration.
4. Copy the opt-in link and send it to the testers.
5. Each tester must open the link using the invited Google account, opt in,
   and install or update AutoDentifyr from Google Play.

Allow time for Play to process the bundle if the update is not immediately
visible.

## 6. Test the Play-installed build

Test the version installed from Google Play, not only a locally installed APK:

- [ ] Fresh install and upgrade from the previous Play version
- [ ] Email/password registration and sign-in
- [ ] Google Sign-In
- [ ] Account sign-out and account deletion
- [ ] Camera permission accepted and denied
- [ ] Live camera inference on a physical device
- [ ] Imported-image inference through the system picker
- [ ] Draft save, reopen, completion, and deletion
- [ ] Vehicle component map selection and findings
- [ ] PDF generation, Files export, native open, and sharing
- [ ] Offline and interrupted-network behavior
- [ ] Large text, screen reader, and narrow-screen behavior
- [ ] Play Console pre-launch report
- [ ] Android vitals for crashes and ANRs

After Android dependency, NDK, R8, or model changes, also run the release
inference check documented in the project README.

## 7. Progress through release tracks

Use this order:

1. **Internal testing** for maintainers and trusted testers.
2. **Closed testing** for representative Appraisers and required production
   eligibility testing.
3. **Production** only after policy declarations and release validation are
   complete.

For personal Play developer accounts created after November 13, 2023, Google
currently requires at least 12 closed-test users to remain opted in
continuously for 14 days before applying for production access. Confirm the
requirement displayed in the account's Play Console because policies can
change.

Promote the validated release between tracks when possible so every track uses
the same reviewed bundle. Do not rebuild between testing and production unless
the rebuilt artifact receives a new build number and repeats this runbook.

For the first production rollout, use a small staged percentage. Monitor
crashes, ANRs, authentication failures, inference failures, and support reports
before increasing the rollout.

## 8. Record the release

Keep the following in the release ticket or pull request:

```text
Version name:
Build number:
Git commit:
AAB SHA-256:
Internal release date:
Closed-test result:
Pre-launch report result:
Physical devices tested:
Known limitations:
Production rollout date and percentage:
```

Never attach the upload keystore, passwords, Firebase secrets, or downloaded ML
model binary to the release ticket.

## Common Play Console problems

**Version code already used**

Increase the build number after `+` in `pubspec.yaml`, rebuild, and upload the
new bundle.

**Upload certificate does not match**

The bundle was signed with a different upload key. Use the registered upload
keystore or follow Play Console's upload-key reset process. Do not replace keys
casually.

**Google Sign-In works locally but fails from Play**

Add the Play app-signing SHA-1 and SHA-256 certificates—not only the local
upload/debug certificate—to Firebase and the Google OAuth configuration.

**Model works in debug but fails in release**

Confirm `best.tflite` was packaged, run the physical-device release inference
check, and inspect R8/native-library compatibility.

**Photo or video permission declaration requested**

Inspect the merged release manifest. AutoDentifyr should use the system picker
for occasional imports rather than request broad media-library access.
