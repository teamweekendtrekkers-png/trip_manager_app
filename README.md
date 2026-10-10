# Trip Manager App

Flutter administration app for Team Weekend Trekkers.

## Shareable PDF brochures

Open a trip, scroll to **Itinerary → Brochure (PDF)**, review the current draft,
then tap **Share / save PDF**. Android's share sheet can send the PDF to another
app or save it using an installed file/cloud app. Export does not save the trip
or write to GitHub. Publish trip edits normally to update the website brochure.

The website's trip pages have **Brochure (PDF)** with preview and download;
compatible browsers also offer native file sharing. Brochures are generated
from the trip data, not separately uploaded files. See `BROCHURE_VERIFICATION.md`.

## Homepage customization

Open **Settings → Homepage Customization** to change the background image
(upload, repository path or HTTPS URL), hero text, and Upcoming Batches.
Choose automatic selection or specific trips/departures; toggle visible card
details and preview the result before publishing. Empty manual selections show
an empty state. Expired dates and inactive trips remain excluded.

Below the batches preview, expand **Statistics**, **Why Travel With Us**,
**Google Reviews** or **Bottom Call to Action** to edit their content/visibility.
Select and order genuine reviews, set Google Maps/review links, and configure
automatic sliding. Reviews are manually curated, not an automatic Google feed.
See [verification and rollout notes](HOMEPAGE_SECTIONS_VERIFICATION.md).

Homepage publishing updates only `js/homepage-config.json`, independently of
trip edits, featured trips and payment/contact settings. Image upload adds the
asset; **Publish homepage** applies it. Publish new trip dates separately first.
Conflicts retain the draft; reload confirms discard. Install and deploy the
matching website changes to enable the new controls on the live homepage.

## Custom trip detail sections

Open a trip and edit **Things to Carry** and **Perfect For**, save the trip,
then use the normal Save to GitHub action. Both sections support adding,
editing, and removing labels. **Use defaults** restores the original labels
for editing; leaving a section empty keeps the website defaults.

These use `thingsToCarry` and the optional `perfectFor` string lists in the
website's trip data. Deploy the matching website renderer before expecting
custom labels to appear. Existing trips and unrelated fields are preserved.

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
