# Trip Manager App

Flutter administration app for Team Weekend Trekkers.

## Download Android and iOS builds

The `Build iOS & Android` GitHub Actions workflow runs automatically after a
push to `main` and can also be started manually from the Actions tab.

1. Open **Actions** in the GitHub repository.
2. Select **Build iOS & Android**.
3. Open a successful run, or select **Run workflow** to create fresh builds.
4. Download the required file from the run's **Artifacts** section:

   - `trip-manager-android-apk` — APK for direct Android installation.
   - `trip-manager-android-aab` — Android App Bundle for Play Console.
   - `trip-manager-ios-unsigned-ipa` — unsigned iOS IPA for later Apple signing.

Artifacts are retained by GitHub Actions for 90 days. The iOS IPA is not
directly installable until it is signed with an Apple Developer certificate
and matching provisioning profile.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
