# Trip information accordions — October 11, 2026

## Delivered locally

The website's About This Trip, What Makes It Special, and What's Included &
Excluded sections are independent native accordions. Trip Manager's Edit Trip
screen includes a **Website section display** panel below Perfect For. Its three
switches choose each section's initial expanded state; content editors remain
unchanged. Save a trip and publish through the existing GitHub action.

The optional `expandedSections` list accepts `about`, `highlights`, and
`includes`. Missing/empty means collapsed. Unrelated trip edits do not introduce
the field. Invalid types, unknown values, and duplicates block publication.
Print expands all three and restores visitor state; PDF brochures retain every
section regardless of its display preference.

No dependency, storage, booking, date, ordering, payment, deployment-monitoring,
or iOS changes were introduced. No live GitHub writes were made. The website's
newer mobile edits were fast-forwarded before implementation; homepage JSON,
featured IDs, and trip data remain byte-for-byte unchanged from that latest
base (`f701a31`). It contains 25 trips and 127 date entries at this verification.
The app base is `4ab1734`.

## Passed regression gates

- Baseline: 56 website tests and 256 Flutter tests passed before source edits.
- `node --test tests/*.test.js`: 61 passed.
- `bash validate-website.sh`: all 8 checks passed, including generated routes,
  JavaScript syntax, 25 trips, and local images.
- `flutter test --no-pub`: 266 passed; existing goldens unchanged, two new
  section-display goldens added for light/dark mode.
- `flutter test integration_test -d emulator-5554 --no-pub`: 60 passed across
  all five suites on Pixel 7 API 34. Two host-only golden comparisons were
  explicitly skipped on Android; they passed in the host run.
- Tests cover all eight initial-state combinations, absent-field preservation,
  invalid schema rejection, draft cancellation, saved-state restoration,
  unchanged brochure content, fake atomic publication with concurrent price
  changes, and true-conflict blocking without either file being written.
- Existing Android suites cover settings restoration, trip editing, dates,
  filters, reorder/delete/publish, homepage/review customization, conflict and
  overwrite paths, deployment monitoring, and PDF export.
- Chromium checks at 375, 768, and 1440 px passed: mouse/touch, Enter/Space,
  independent panels, unchanged itinerary behavior, print restoration,
  brochure generation, no-JavaScript fallback, managed preferences, no horizontal
  overflow, booking/payment parity against the pre-change template, and actual
  checkout navigation. Screenshots were visually inspected.
- `flutter analyze --no-pub`: exactly the same 32 baseline findings, all in
  unchanged root `test_sync_debug.dart` (one unused import and 31 print infos).
  The full diagnostic lists were compared; no new production/test diagnostics.
  The analyzer exits nonzero because of these existing findings.
- `git diff --check`: passed in both repositories. New text files were also
  checked for whitespace errors; dependency manifests/lockfiles are unchanged.
- Debug and release APK builds passed using
  `/usr/lib/jvm/jdk-17.0.18+8`. Standard build commands regenerate Flutter's
  ignored plugin metadata after integration tests; no dependency upgrades or
  generated-source hand edits were used.

## Device test input correction

Initial full device runs exposed pre-existing simulated-typing races in the
homepage/review fixture tests. Their `tester.enterText` messages were competing
with the emulator's real Gboard connection. Flutter documents this limitation
in [TestTextInput.enterText](https://api.flutter.dev/flutter/flutter_test/TestTextInput/enterText.html).

Those two device harnesses now register/unregister the test keyboard per test
using the existing integration binding. Assertions were retained, input frames
are settled, and confirmed reload additionally asserts that the remote fixture
was fetched. The final full device run passed. No homepage or review production
code was changed for this test correction. Native third-party keyboard behavior
is not claimed to be exhaustively verified by those simulated-input suites.

## Recovery and evidence

Recovery snapshot:
`/home/simplifybytes/trip-sections-recovery-20261011-5LQ2xD`

It contains a verified full `working-trees.tar.gz` of both repositories,
including Git history, ignored/untracked files, plus HEADs, statuses, binary
diffs, and an archive manifest. The snapshot predates edits; fetched newer
website commits are also recoverable from its Git objects. Extract into a
separate empty directory if inspection is needed, not over a working repo.

Local logs:

- `/tmp/trip-sections-website-test.log`
- `/tmp/trip-sections-website-validation.log`
- `/tmp/trip-sections-final-test.log`
- `/tmp/trip-sections-android-all-final.log`
- `/tmp/trip-sections-final-analyze.log`
- `/tmp/trip-sections-debug-build.log`
- `/tmp/trip-sections-release-build.log`

The optional native screenshot gate is reproducible with:

```sh
JAVA_HOME=/usr/lib/jvm/jdk-17.0.18+8 flutter drive \
  --driver=test_driver/trip_sections_driver.dart \
  --target=integration_test/trip_sections_flow_test.dart \
  --dart-define=TRIP_SECTIONS_SCREENSHOTS=true -d emulator-5554
```

It writes light/dark PNGs to a new temporary directory printed by the driver.
Run a normal APK build afterward to replace the integration debug APK.

## Verification boundaries

These changes are local and uncommitted, not pushed or deployed. Hosted CI and
the live site have therefore not been verified for this update. Deploy the
website support before distributing the new app; older app versions deliberately
block unfamiliar trip fields rather than silently discard them.

The browser baseline and updated page both emitted an existing early image-load
`hideLoader is not defined` error; this update introduced no new page errors.
Testing does not provide a literal 100% guarantee across every browser/device,
live API race, or future data change. No regression was found in the tested flows.

## Final artifact checks

- Native screenshot driver passed after mounting each preview theme fresh
  (avoiding an intermediate theme-animation frame). Both light/dark device
  screenshots were visually inspected:
  `/tmp/twt-trip-sections-device-YKBBGO/trip-sections-light.png` and
  `/tmp/twt-trip-sections-device-YKBBGO/trip-sections-dark.png`.
- Website screenshots: `/tmp/twt-trip-sections-browser-NfvbFL`, including
  collapsed/expanded/mobile/tablet/desktop states. The browser capture waits for
  paint after scrolling; all functional assertions remain unchanged.
- Normal debug and release APKs were rebuilt after the screenshot integration
  run. Debug is approximately 169 MiB; release is 54.2 MB as reported by Flutter.
- The release APK was installed on Pixel 7 API 34 and cold-launched successfully:
  Android reported `Status: ok`, `LaunchState: COLD`, and `TotalTime: 910` ms.
  The app process remained running on the subsequent check.
- Release artifact:
  `build/app/outputs/flutter-apk/app-release.apk`.
- Release SHA-256:
  `107d1d5ac2cabe0eb1a8aa6b28b993e53d1549b6a0b7b597cd6e39d7454f148f`.

No failed mandatory local regression gate remains. Hosted deployment/CI and
exhaustive real-world device coverage remain outside this local verification.
