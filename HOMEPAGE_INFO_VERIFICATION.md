# Editable homepage steps and reasons

The homepage now shows **How It Works** and **Why Thousands Choose Us** in place
of **Why Travel With Us**. Open **Homepage Customization** in Trip Manager and
expand either new panel to edit headings, optional badge/subtitle, icons,
card text, card colour, visibility, ordering and card additions/removals.
Reason cards also have an optional highlighted value. Up to eight cards are
supported in each section. Publish homepage remains the only publication action.

Only the dedicated homepage JSON is published, using the existing atomic commit
and optimistic-concurrency service. The two sections merge independently;
simultaneous edits to one card list are reported as conflicts. Unknown fields,
invalid types, duplicate IDs and unsupported colours block publication.

Legacy `whyUs` data remains preserved, but is no longer displayed or edited.
Legacy hidden visibility is inherited until the replacement section has explicit
settings. Existing hero/background, upcoming departures, statistics, reviews,
CTA, trip data, booking, brochures and app settings storage are unchanged.
Older app versions reject unfamiliar fields instead of erasing new content;
install the updated app before publishing edits to these sections.

Recovery: the pre-existing complete working-tree snapshot is
`/home/simplifybytes/trip-sections-recovery-20261011-5LQ2xD`.
An incremental pre-change snapshot of both dirty working trees, binary diffs,
HEADs and statuses is
`/home/simplifybytes/homepage-cards-recovery-20261011-dMj525`.
The previous review-autoplay changes are preserved. No stash/reset/commit/push
or live website write was performed for this update.

## Verification

- Website Node suite: 74 tests passed, including cross-repository default parity.
  That parity check is skipped in standalone website CI without an app checkout;
  all website behavior tests remain mandatory.
- Website validation: all eight checks passed.
- Real Chromium: 375/768/1440px layouts, custom/hidden sections, reordered and
  hidden steps, literal text safety, optional values, no-JavaScript fallback,
  review autoplay/resume without Play/Pause, swipe/keyboard and unchanged
  navigation/booking/WhatsApp targets passed. Screenshots under
  `/tmp/homepage-info-*.png` and `/tmp/homepage-sections-*.png`.
- New app tests cover migration, strict validation, merging/conflicts,
  fake GitHub publication/reload, and editing all controls in light/dark mode.
  Four new goldens were generated; existing goldens were not regenerated.
- `flutter test --no-pub`: all 278 tests passed, including full-screen edit,
  publish, reload and preservation of unrelated settings.
- `flutter analyze --no-pub`: the same 32 pre-existing findings, all in
  `test_sync_debug.dart` (one unused import and 31 print notices). The complete
  diagnostic list exactly matches the baseline; no new diagnostics.
- Manual inspection: desktop/phone website screenshots and a native Android
  editor screenshot (`/tmp/homepage-info-android.png`) were inspected.
- `git diff --check`: passed in both repositories; earlier uncommitted trip
  section work and review-autoplay regression tests were compared to the
  incremental snapshot and remain unchanged.

- Android: `flutter test integration_test -d emulator-5554 --no-pub` with the full
  JDK passed all 72 tests on the available Pixel 7 API 34 emulator. Two existing
  host-only goldens were skipped on Android and passed in the host suite.
  The new four goldens run on the host; their editing flows also passed natively.
  Brochure, trip section, general admin, review selection and full homepage
  publication/reload regression flows all passed.

- Normal debug and release APK builds passed using
  `/usr/lib/jvm/jdk-17.0.18+8`; the debug APK is not an integration-test build.
  APKs: `build/app/outputs/flutter-apk/app-debug.apk` and
  `build/app/outputs/flutter-apk/app-release.apk` (release 54.2 MB).
  Release SHA-256:
  `88d58a1af80242300040db94f2a042f7eb7a2b0f2033dc020890c9ed974be3a3`.
- Release APK installed with `adb install -r` (no uninstall/data clearing) and
  cold-launched successfully on the same emulator: status OK, launch state COLD,
  total time 1686 ms; the app process remained running afterward.

Logs: `/tmp/homepage-info-website-test.log`, `/tmp/homepage-info-final-test.log`,
`/tmp/homepage-info-android.log`, `/tmp/homepage-info-analyze.log`,
`/tmp/homepage-info-debug-build.log`, `/tmp/homepage-info-release-build.log`.
Hosted CI, live deployment and actual Google review writes are not verified;
all automated publishing tests use injected fake GitHub services.
