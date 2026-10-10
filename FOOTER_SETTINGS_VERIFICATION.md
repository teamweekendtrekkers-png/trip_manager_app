# Editable website footer and UPI visibility

Open **Homepage Customization → Website Footer (all pages)**. Edit branding,
community description, address/contact details, headings, essential navigation
labels, social-icon visibility and copyright. Optional information links support
add/edit/hide/reorder/remove (maximum eight). Essential Home, All Trips, About Us
and Contact destinations cannot be removed or redirected.

**Show Pay via UPI in footer** hides only the website footer payment column.
It does not disable checkout UPI, change the actual payment ID, alter payment
security or affect booking. Actual IDs remain under
**Settings → Website Contact & Payment**. Footer WhatsApp/Instagram overrides
are optional; blank values inherit the existing synchronized website links.
No legal policy content or unavailable routes are generated.

Edits remain in the draft until **Publish homepage** is confirmed. Only
`js/homepage-config.json` is published through the existing atomic,
optimistic-concurrency service. Independent footer fields merge; competing
branding/link-list changes report conflicts. Invalid types, unsupported fields,
unsafe links, duplicate IDs and malformed contacts block publication.
Install this manager version before publishing new footer fields; older
versions reject unfamiliar configuration rather than erase it.

The shared website footer covers Home, Trips, generated and query-based trip
details, About and Contact. Checkout retains its compact footer; no payment
column is introduced there. Footer UPI starts hidden until valid settings load;
network/JSON failure and disabled JavaScript cannot reveal the column.
Legacy valid version-1 configuration keeps the existing visible-UPI default.

## Recovery and scope

Incremental pre-change recovery snapshot, including all earlier dirty/untracked
files, HEAD, status and binary diff for both repositories:
`/home/simplifybytes/footer-recovery-20261011-YHUw6Y`.
Original complete working-tree snapshot:
`/home/simplifybytes/trip-sections-recovery-20261011-5LQ2xD`.

Earlier trip-section, review-autoplay and homepage-card work is preserved.
Twenty-four earlier app files and eleven earlier website files were compared
byte-for-byte with the incremental snapshot. Only the intended shared integration
files differ. Trip data (25 trips, 127 current date entries), featured data,
published homepage configuration, security.js and main.js match HEAD byte-for-byte.
No dependency upgrade, settings-storage migration, stash/reset/commit/push,
live publication, booking or payment was performed.

## Verification

- `flutter test --no-pub`: all 287 tests passed, including two new footer
  light/dark goldens and full-screen edit → publish → reload. Existing goldens
  were not regenerated.
- Website Node suite: 81 tests passed, including Dart/website default parity,
  legacy compatibility, safe URLs, explicit empty/hidden lists and fail-closed
  UPI visibility. The cross-repository parity test skips in standalone website
  CI without an app checkout; behavior tests remain mandatory.
- Website validation: all eight checks passed.
- Additional legacy shell checks passed: website 142, trip data 156,
  responsive 19, SEO/accessibility 36, performance 33. These scripts still
  report advisory warnings: one Razorpay-key heuristic warning, one touch-style
  warning, 23 SEO advisories and 127 performance/image advisories. They are not
  equivalent to a live payment, SEO or performance audit.
- Real Chromium checks passed at 375/768/1440px: editable and hidden footer,
  fixed navigation, optional information links, safe literal text, unchanged
  checkout/booking DOM, actual secured UPI-copy handler, contact override/reset,
  generated trip routes, delayed/failed configuration and no-JavaScript fallback.
- Existing browser gates passed: review autoplay/resume without Play/Pause,
  keyboard/swipe/reduced-motion behavior, editable homepage cards, collapsible
  trip sections, brochure generation and checkout navigation/payment parity.
- Screenshots inspected: `/tmp/footer-hidden-375.png`,
  `/tmp/footer-hidden-1440.png`, new light-mode golden and native dark-mode
  Android information-link editor `/tmp/footer-android-editor.png`.
- Existing trip-image browser exception `hideLoader is not defined` occurs
  on the original HTML too; no new browser exception was introduced.
- Android: `flutter test integration_test -d emulator-5554 --no-pub` passed
  all 81 tests on the available Pixel 7 API 34 emulator. Two existing host-only
  goldens skip on Android and pass on the host. The new footer light/dark
  editing flows, full-screen publication/reload and existing admin, conflict,
  brochure and homepage regression flows passed. No emulator was stopped.
- `flutter analyze --no-pub`: exactly the same 32 baseline findings, all in
  root `test_sync_debug.dart` (one unused import, 31 print notices). Complete
  diagnostic lists were diffed; no new diagnostics and none in new code.
- `git diff --check`: passed in both repositories.
- Normal debug and release APK builds passed using the full JDK
  `/usr/lib/jvm/jdk-17.0.18+8`. The final debug APK is not an integration-test
  build. Release APK: `build/app/outputs/flutter-apk/app-release.apk` (54.3 MB).
  Release SHA-256:
  `ead9a8ad5e2143fc8918640a0fb627da851456c6b2928cd43be5485f75399606`.
- Release APK installed with `adb install -r` (no uninstall/data clearing) and
  cold-launched successfully on the same emulator: status OK, COLD,
  total launch time 3109 ms; app process confirmed running afterward.

Logs: `/tmp/footer-final-test.log`, `/tmp/footer-website-test.log`,
`/tmp/footer-validation.log`, `/tmp/footer-browser.log`,
`/tmp/footer-homepage-browser.log`, `/tmp/footer-trip-browser.log`,
`/tmp/footer-legacy-*.log`, `/tmp/footer-android.log`,
`/tmp/footer-analyze.log`, `/tmp/footer-debug-build.log`,
`/tmp/footer-release-build.log`.

Hosted CI/deployment and real payment transactions are not verified. All
publishing tests inject a fake GitHub service; no tests write to the live website.
Passing these checks provides regression evidence, not a literal 100% guarantee.
