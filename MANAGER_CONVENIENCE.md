# Manager 1.7.0 (build 8)

This update improves the manager app. It does not change website payment methods or trip data formats.

## Everyday use

- Dashboard: Add trip, Edit trips, Departures, Publishing status, Open live website.
- Trips: search plus All, Active, Draft, Upcoming and Inactive filters. Filters combine with the existing Featured filter. Reordering stays disabled while filtered.
- Existing grouped trip editing, required-field checks, preview and separate Review & publish remain available.
- Edit trip: Open published trip uses its saved public address rather than an unsaved new address.
- Publishing status retains the last successful workflow and failure reporting. A saved draft or GitHub commit is not presented as proof the website is live.

## Draft controls

- Drafts still save automatically on this device.
- Discard changes restores the last explicit local save (or the editor opening state). A confirmation explains this.
- Delete saved draft removes that editor draft. For an existing published trip, it also resets only that trip in the workspace to the last loaded published version. Other trip drafts remain intact.
- New trip drafts return to the initial editor form. Unpublished trips with no published counterpart return to the version loaded in the editor.
- Leaving the editor offers Save draft & leave, Discard or Keep editing. Discard retains the last explicit local save; delete saved draft is the separate action for removing it.
- Discard and delete never publish or modify the live website. Conflicting saved drafts remain reviewable.

## Version and updates

- Menu and Settings display the installed package version and build number.
- Settings includes Check for updates, What’s new and Open downloads.
- Update checks read only the manager repository's latest successful main-branch push build and its exact commit's version. Downloads must still be available and unexpired for this device before reporting up to date.
- Failed, pending or unverified builds do not produce an up-to-date claim. Downloads use the existing GitHub Actions distribution and may require GitHub sign-in.
- Copy app details includes only the installed version, platform and operating system version. It excludes account details and repository tokens.

## Installation

A new manager installation is required to access these controls. Existing application identifiers and storage names are retained. Android release signing remains the existing project configuration; installation compatibility depends on the installed app and new APK sharing the signing key. Do not uninstall an existing app merely to work around an installation error without first preserving its local drafts/settings.
