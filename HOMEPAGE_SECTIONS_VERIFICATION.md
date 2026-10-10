# Homepage sections verification — October 10, 2026

## Scope and recovery

Full pre-edit copies (including ignored/untracked files and .git metadata):
`/home/simplifybytes/homepage-sections-recovery-20261010-1mcH8E`.
Website baseline `1b4c6b251d14f3b204fc60b47345bba8e796d894`; app baseline
`a41b936433b4b5f3842ea8a7176eac2f65b49a3f`. Both started clean.

These checks were recorded before publication. No live website data, Google
reviews, bookings or messages were written during implementation/tests.

The existing Homepage Customization screen now edits statistics, reasons to
travel, curated Google reviews and the bottom call to action. See the website's
`HOMEPAGE_SECTIONS.md` for controls, schema compatibility and usage.

## Verification

- Full Flutter suite: **256 passed**, including every unchanged screen golden
  and two new light/dark review-editor layout goldens. Tests cover validation,
  ordering/selection, additions/removals, draft isolation, exact homepage-only
  publication, concurrent edits, unsafe links and confirmed reload of unchanged
  remote data. A new field-state reset prevents stale text after discard/reload.
- Website unit/regression suite: **56 passed**; all eight website validation
  checks passed (including all 25 trip records).
- Real Chromium: 375/768/1440 layouts, actual emulated mobile touch gestures,
  automatic/manual sliding, arrows,
  keyboard navigation, pause/resume state, reduced-motion behavior, selected
  reviews/order, Google links, text injection safety, failed-photo initials,
  single/empty review sets and hidden sections passed. Navigation, hero, footer,
  trips and WhatsApp targets matched the baseline page. No baseline or new
  browser exceptions were observed. Screenshots: `/tmp/homepage-sections-*.png`.
- Website and Flutter section defaults match exactly; all six original reviews,
  original statistics and Why Travel With Us text are retained as defaults.
- Analyzer: **32 pre-existing findings only**, all in unchanged
  `test_sync_debug.dart` (one unused import, 31 `avoid_print` infos).
  No diagnostics in new production/test code; analyzer still exits nonzero
  because of the unchanged baseline.
- Both repositories pass `git diff --check`. Website trip/featured/homepage JSON,
  booking/checkout, trip-detail/brochure files and main script remain unchanged.
  App dependencies, storage, providers, GitHub publication services, trip editor,
  Android and CI configuration remain unchanged.
- Full final Android integration directory: **52 passed** on Pixel 7 API 34,
  including existing admin, homepage and brochure flows plus new section flows.
  All GitHub publication/conflict simulations use injected fake clients, never
  the live website. Debug APK built successfully with the full JDK 17.
- Release APK built successfully (54.2 MB) using
  `/usr/lib/jvm/jdk-17.0.18+8` and the standard `flutter build apk --release`.
  Immediately after device integration, a `--no-pub` release attempt hit stale
  generated integration-test plugin registration. The standard build regenerated
  that ignored metadata and passed; no source, dependency or lockfile change
  was needed. APK: `build/app/outputs/flutter-apk/app-release.apk`.
- The standard `flutter build apk --debug` also passed after integration. The
  final release APK installed successfully and cold-launched on Pixel 7 API 34
  (`am start -W`: Status ok, LaunchState COLD). The test-started emulator was
  stopped after verification.

## Publication follow-up: failed website checks

The website run at `1bb1b5c` failed six JavaScript behavior tests after a valid
homepage customization. The tests incorrectly loaded mutable
`js/homepage-config.json` as their fixed default fixture. Different hero images
and selected trip IDs therefore broke synthetic-trip assertions and fallback
comparisons. The website runtime was not the source of those failures.

The behavior suites now use `tests/fixtures/homepage-defaults.json`. A regression
gate reruns all 15 homepage/section behavior tests in an isolated child process
with customized hero, selection, visibility, fields and review content. Another
test verifies the actual published choices still load without resetting them.
The final full website suite passes **56 tests** and the app rerun passes **256**.
No validation job or behavior assertion was disabled.

The three newer website commits were fast-forwarded before publication. The
uploaded background image and published homepage JSON remain byte-for-byte
unchanged from `1bb1b5c`. Pre-publication full working-tree recovery copies:
`/home/simplifybytes/homepage-publish-recovery-20261010-VLGrV4`.

## Limits and rollout

No software change can carry a literal 100% guarantee. These are local and
Pixel 7 API 34 emulator checks, not physical-phone/all-browser guarantees. The
deployed version of these section changes was not tested during implementation.

Google reviews/overall rating are manually curated; no scraping, automatic feed,
Google API key or authenticity verification is introduced. Use genuine reviews
and their Google Maps share links, and keep relative date labels accurate.
New reviews start hidden and must have a name and text before publication.

Deploy the website code and install this manager before publishing sections.
Original version-1 homepage JSON loads unchanged. After publishing new
`sections` fields, old managers safely refuse to overwrite homepage settings
containing those unfamiliar fields; ordinary trip management uses its unchanged
schema. Different section fields merge; concurrent edits to the same item list
are conservatively blocked rather than losing changes.
