# Bookings and payment review

This screen requires the matching website change and database migration in
`teamweekendtrekkerwebsite/supabase/migrations/20261016_booking_review.sql`.
Apply that migration to the existing Supabase project, then create or invite a
Supabase Auth administrator. Using trusted Supabase administrator tools, set
that user's **app_metadata** to include the boolean `trip_manager_admin: true`.
Sign in again after granting this claim. Customer-editable user_metadata never
grants access.

The app loads the existing project's public anon key from the configured
website repository, signs in using the administrator's email/password and keeps
the resulting token only in memory. GitHub repository access alone does not
provide booking access. Never configure a service-role key in the app.

Search by booking reference, customer, phone or transaction ID. Results are
paginated in groups of 50. Verify actual credit in your bank/UPI account before
marking a reported payment verified. Reviews may be marked pending, verified or
rejected with a note. A concurrent update is rejected until you refresh. Payment
review does not confirm trip availability or change the existing booking status.

Use Sign out when finished. Closing the screen clears the in-memory token. The
database rejects every unauthenticated/non-administrator call even if a client
tries to bypass the sign-in screen. No UPI account-history tracking is added.
