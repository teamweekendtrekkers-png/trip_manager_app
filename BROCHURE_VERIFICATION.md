# Brochure verification — October 10, 2026

## Recovery and publication

Full pre-edit repository copies, including ignored/untracked files and Git
metadata: `/home/simplifybytes/brochure-recovery-20261010-6rw7Hl`.
Baselines: website `f3aa74e3e8f6d24b437628f76607e6949104a2cc`, manager
`c77c753052f7c9606609e048ea0ad6e9f5e1bf5b`. Both started clean. These checks
were recorded before publication; no live data, remote branches or messages
were changed during implementation or tests.

## Scope

Website: a trip-detail brochure button, preview, PDF download and conditional
native share. Manager: **Itinerary → Brochure (PDF)**, read-only unsaved draft
preview, and PDF generation through the existing Android sharing plugin.
Existing trip schemas, data files, settings, booking/payment flows, GitHub
publication, dependencies and CI configuration were not changed.

PDF pages are rasterized A4 for Unicode/emoji portability, with a clickable
booking footer. Body text is not selectable/searchable or accessibility-tagged.
This tradeoff is intentional; no runtime font/CDN downloads are introduced.

## Verified

- Website suite: **48 tests passed**, including all pre-existing tests.
- Flutter suite: **244 tests passed**, including all unchanged screen goldens.
- Actual Chromium: preview/download/share fallback, failure handling, legacy and
  generated routes, and dialog layout at **375, 768 and 1440 pixels** passed.
  Booking button, date/people inputs, price, UPI panel, floating booking control
  and WhatsApp link matched the pre-change template.
- All **25 real catalog trips** generated complete brochures: **91 PDF pages**
  in total, maximum file approximately **1.3 MB**. Poppler `pdfinfo` accepted
  every PDF as unencrypted A4 PDF 1.4 without JavaScript. All itinerary activities
  were retained in order, and export did not mutate source data.
- Flutter's real long-itinerary renderer generated a **15-page** PDF, independently
  accepted by Poppler. The real Android renderer generated a **2-page** fixture
  PDF with rupee/emoji text; its rendered first page was visually inspected.
- Pixel 7 API 34: the brochure suite plus opt-in native-share gate passed
  **12 tests**. Android's actual chooser displayed **Sharing 1 file** and the
  PDF filename; dismissing it returned safely to the app. No recipient selected.
- Full Android integration directory: **40 tests passed** across existing admin,
  homepage and brochure flows, using fake GitHub clients (no live writes).
- Unknown/empty/malformed values, inactive trips, stale selected dates, safe
  filenames/booking links, PDF xref offsets, cached exports, retry, duplicate
  taps and leaving during generation are covered.
- Analyzer baseline unchanged: **32 findings** in unchanged
  `test_sync_debug.dart` (one unused import, 31 `avoid_print` infos). No findings
  in new production code. Analyzer therefore still exits nonzero.
- `git diff --check` passed in both repositories. Website trip/featured/homepage
  data, checkout, Flutter dependencies, GitHub services, providers and Android/CI
  configuration remain unchanged.
- Debug and release APKs built successfully with
  `/usr/lib/jvm/jdk-17.0.18+8`. The release APK installed and cold-launched
  successfully on the Pixel 7 emulator. Existing signing is unchanged.
  Outputs: `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`.

## Remaining limits

Literal 100% certainty is impossible. A physical phone, delivery to WhatsApp or
other recipients, every browser/OS version and the deployed live brochure have
not been directly verified. Browser native sharing was simulated for the web
gate; the real Android manager share sheet was directly exercised. The reference
site could not be fetched by the browser research tool; the provided screenshot
and requested itinerary-to-PDF behavior guided the implementation.

The existing trip-detail template produced a `hideLoader is not defined`
image-load race in the baseline Chromium run as well as updated pages. It is
pre-existing and unchanged; no new browser exceptions were observed.
