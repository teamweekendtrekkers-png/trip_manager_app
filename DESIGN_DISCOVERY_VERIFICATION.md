# Design/discovery update verification — 2026-10-11

This update preserves pre-existing uncommitted work. No stash, reset, commit, push or live publication was performed.

## Recovery

- Persistent pre-edit source snapshot, original repository HEAD/status and binary diffs: `/home/simplifybytes/design-recovery-20261011-HHlAST`.
- Complete compressed pre-edit working trees, including ignored build/cache files: `/home/simplifybytes/design-recovery-20261011-HHlAST/working-trees.tar.gz`. SHA-256 verification passed after relocation from temporary memory storage to disk. This complete archive is the authoritative recovery snapshot.
- Website image assets and source were also extracted for convenient comparison. This extracted copy excludes reproducible build/cache outputs and the Python virtual environment; those remain in the complete archive.
- A low-disk-space emulator restart required clearing 4.2 GB of generated Flutter caches. Before removal, all 69 cache directories and the generated registrant were archived, and `tar --compare` verified the archive against the originals. This supplemental, post-test cache archive is now at `/dev/shm/travel-design-recovery-20261011-l8ENHN/flutter-build-cache-before-verification.tar.gz` (temporary; does not survive reboot). Original pre-edit caches also remain in the complete persistent archive. Source, settings and uncommitted work were not deleted. Initial failed-test comparison images are retained in the persistent snapshot under `initial-golden-failure`.

Initial website HEAD: `f701a31`; initial manager HEAD: `4ab1734`. Existing dirty and untracked files were included before edits. Neither repository's HEAD was changed.

## Baseline

- Website: 81 tests passed.
- Flutter: 287 tests passed.
- Analyzer: 32 existing findings, all in the root `test_sync_debug.dart` diagnostic script (one unused import and 31 print findings).
- Existing browser exception: `hideLoader is not defined`. This unrelated legacy gallery issue was recorded, not silently counted as a new passing behavior.

## Final gates

Final gate results follow.

| Gate | Result |
| --- | --- |
| Website `node --test tests/*.test.js` | 101 passed |
| Website validation script | 8/8 checks passed |
| Flutter full unit/widget/golden suite | 310 passed after final UX adjustment |
| Existing golden files | All 21 pre-edit images byte-identical |
| Chromium discovery | Passed at 390, 768 and 1440px |
| Chromium trip decision/date handoff | Passed at 375, 768 and 1440px |
| Chromium existing trip accordions/brochure/checkout | Passed at 375, 768 and 1440px |
| Chromium existing review slider | Passed at 375, 768 and 1440px |
| Chromium footer/payment preservation | Passed at 375, 768 and 1440px |
| Android emulator integration | 99 distinct checks passed across initial run and targeted reruns; two screenshot checks skipped on device and passed on host |
| Analyzer baseline comparison | Exact same 32 findings as baseline; none in newly added code |
| Debug and release APKs, full JDK 17 | Both passed using `/usr/lib/jvm/jdk-17.0.18+8`; release APK 54.5 MB |
| Both repository whitespace checks | Passed |

Browser checks use local fixtures, block external booking/payment calls and never publish. Mobile/desktop screenshots were inspected for layout and overflow. Android checks use the existing Pixel 7 API 34 emulator and injected fake services; no emulator data reset is required.

Normal app artifacts (not integration-test runners): `build/app/outputs/flutter-apk/app-debug.apk` and `build/app/outputs/flutter-apk/app-release.apk`.

Release APK SHA-256: `dcff4645db38270314193109c8898877e48e6beab7f39f4f996596eef69ada3a`. Baseline and final command logs are retained in the recovery snapshot's `verification-logs` directory, including the initial failed emulator invocation and successful targeted reruns.

The initial Android invocation caught an off-screen test tap and then lost the emulator. The harness now explicitly scrolls, settles and verifies hit testing. The same AVD was restarted with software graphics, without wiping its data. The new card flow and both interrupted homepage suites were rerun together: all 58 passed. The other five suites contributed 41 distinct passing checks. Thus all eight integration files were exercised successfully, but not in one uninterrupted invocation. Host golden tests cover screenshots skipped on Android.

## Data preservation

An independent comparison against the pre-edit snapshot confirmed all 25 trip IDs and their source order, all 127 current date entries, and every pre-existing trip field are unchanged. Only optional card metadata was added to 13 active trips. Common pickup/helper source, `featured-trips.js`, `main.js`, `security.js`, the brochure implementation and `checkout.html` are unchanged from the pre-edit working tree. Existing homepage configuration choices are unchanged except the exact stock inclusions claim replaced with accurate package-specific wording.

The source-preserving manager writer round-trips the actual adjacent website records and homepage configuration. These additional cross-repository tests skip when the website checkout is absent; fixture-based schema tests always run independently.

## Scope and remaining uncertainty

No software change can carry a literal 100% guarantee. Hosted GitHub CI, production deployment, real-token publication, real Google review freshness, live payments, physical Android hardware and iOS were not exercised. The Android workflow already tests before building on `main` and `master`; it was not broadened or changed. Existing unrelated analyzer findings and gallery exception remain as documented above.

The new manager must be installed before publishing new optional trip fields; older managers intentionally block unknown fields. User instructions and supported fields are documented in the website's `DESIGN_DISCOVERY.md`.
