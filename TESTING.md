# Test coverage and maintenance

Run the manager suite with `flutter test`. CI checks the current website's
`main` branch out into `.contract-website`, records its commit SHA in the
job log, and sets `WEBSITE_REPO_PATH` before running the full suite.
Only the two public data files needed by the compatibility tests are checked out.

To include website compatibility checks locally, point `WEBSITE_REPO_PATH`
at a website checkout. For example, in PowerShell:

```powershell
$env:WEBSITE_REPO_PATH = 'C:\TravelBooking'
flutter test
```

Without that variable, local tests look for `../TravelBooking`. The two
compatibility tests may skip in an app-only local checkout. In CI, or when an
explicit website path is supplied, missing files fail the tests.

## Coverage kept

- Payment settings, UPI profiles, coupons, and manual payment review permissions.
- Date parsing and booking cutoffs, editor validation, and data preservation.
- Concurrent edits, repository/branch targeting, atomic publishing and conflicts.
- Real screen workflows, keyboard/touch editing, layout and accessibility checks.
- Full trip-data round trips and homepage configuration against actual website data.

Similar tests at different layers are intentional: a parser test cannot replace
an editor interaction or a publication test that catches a failed network write.

## Consolidation

- Removed the static Text-widget smoke test; it never instantiated the manager.
- Removed `comprehensive_app_test.dart`: its parser, round-trip, source-span,
  settings persistence and invalid-contact checks repeated focused suites.
- Combined the editor field-name check with its value-preserving round trip.
  The retained test checks complete nested values and aliases, not only strings
  in generated JavaScript.
- Removed the editor suite's repeated source-span test; parser and source-preserving
  persistence tests still check that edits leave surrounding JavaScript intact.
- Moved the optional live trip round-trip coverage out of the card UI suite into
  the website contract suite, which now checks every parsed field.
- Kept the safety, payment, conflict, workflow and screen regression tests.
