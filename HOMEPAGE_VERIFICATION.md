# Homepage customization verification — October 10, 2026

Use **Settings → Homepage Customization**. Deploy the matching website files
and install the rebuilt manager together. These checks were recorded before
publication; no production website data or GitHub branches were modified during
testing.

## Recovery and scope

Complete pre-edit working-tree copies, including ignored/untracked files and
Git metadata, are at:
`/home/simplifybytes/homepage-customization-recovery-20261010-wZduwN`.
Both repositories were clean before editing. Their baseline commits were:

- Website: `0d6359cc24e99bcc1948fa41f97893c2ff81eb17`.
- Manager: `b819d0009b61a8aeb5e75494679734fbfdd7dda2`.

Homepage configuration is independent of trip data. Publishing replaces only
`js/homepage-config.json`; uploading a background adds an image asset separately.
Trip/featured data files, booking/payment/contact flows, trip providers, date
utilities, dependencies and CI configuration were not changed.

## Passed checks

- `flutter test --no-pub`: **233 passed**, including all existing regression
  tests/goldens and two new light/dark homepage editor goldens.
- Pixel 7 API 34 Android emulator: existing `admin_flow_test.dart` **5 passed**;
  new `homepage_flow_test.dart` **24 passed**, comprising 15 domain/service
  checks and 9 editor interaction scenarios. Services and image previews were
  injected fixtures: no live GitHub writes.
- Website `node --test tests/*.test.js`: **40 passed**.
- `bash validate-website.sh`: **all 8 checks passed**; all 25 trips present.
- Actual Chromium comparison against the pre-change homepage: default hero,
  batch text, featured links and hero action links match. Custom trip/departure
  selection, optional detail fields, literal text escaping, hidden section,
  unavailable-configuration fallback and background-image fallback passed at
  **375, 768 and 1440 pixels**, without horizontal page overflow.
- Read-only cross-language compatibility: all **25 current website trips**
  parse without errors; committed homepage defaults match Dart defaults.
  Fixed October 10, 2026 preview retains the existing chronological batches.
- Three-way merge, true-conflict blocking, branch-race retry, malformed/unknown
  schema blocking, explicit-404 creation and homepage-only commits passed.
- `flutter analyze --no-pub`: **no new diagnostics**. The same 32 baseline
  findings remain exclusively in unchanged `test_sync_debug.dart`: one unused
  import and 31 `avoid_print` infos. The command therefore exits nonzero;
  this is not a clean analyzer result. No findings in new production/test code.
- `git diff --check` passed in both repositories. Website trip and featured
  data and Flutter dependency files remain unchanged.
- Standard debug and release APK builds passed using
  `/usr/lib/jvm/jdk-17.0.18+8`. Outputs are
  `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`.
  Existing signing configuration was not changed. The release APK also
  installed successfully and cold-launched on the emulator to the expected
  first-run GitHub setup prompt.

## Limits

No literal 100% guarantee is possible. Production deployment, a physical Android
phone, real gallery selection/upload and external-image availability were not
directly exercised. Upload behavior was tested through an injected image result;
GitHub publication/conflicts were tested with in-memory clients. Tests never
published or changed the live website. Existing automated regression coverage
passed; this is evidence, not a claim that every possible interaction is covered.
