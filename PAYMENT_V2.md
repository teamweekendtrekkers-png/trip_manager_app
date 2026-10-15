# Trip Manager 1.8.0

Payments & coupons now has two saved QR/UPI profiles. Choose the profile to edit,
enter its matching UPI ID, receiver name and original QR image, then choose Use
this account. Review the active-account preview and publish. Editing the backup
does not activate it. Existing settings migrate into Primary; Backup starts empty.
There is no payment-account-history tracking.
The published commerce document uses version 2. Older manager releases reject
that version, preventing their single-account editor from changing only part of
the new payment profile.

UPI payment is the default for every bookable trip. Under Allow booking requests
for selected trips, check only the trips that may also accept an availability
request. Customers still see payment selected first. The customer page offers
scan/download QR and Copy UPI ID; app-launch buttons are removed.

The Manage departures screen offers Duplicate departure (choose a new range)
and Close/Reopen bookings. Closing preserves the date in the editor while excluding it from the
website's bookable dates. The dashboard now counts inactive and bookable trips
alongside missing dates and unpublished changes. Existing bulk dates, source
preservation, previews, draft recovery, version recovery and publishing status
are retained. Payment settings display unpublished/published status explicitly.

See BOOKING_REVIEW_SETUP.md for the separately authenticated payment-review
screen. Deploy the matching booking-request function before releasing the website
v2 flow; the previous function restricts payments to approved departures.
