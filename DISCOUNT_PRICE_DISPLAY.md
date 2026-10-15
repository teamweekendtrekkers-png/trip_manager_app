# Manager 1.7.1 (build 9): original and discounted prices

In Edit trip → Dates & price:

- Price (₹): original amount, for example ₹6,599.
- Discounted Price (₹): reduced amount, for example ₹5,999.

The Trips list displays the original amount smaller, muted and crossed out. The discounted amount is bold and green. Prices wrap on narrow cards so the date and fare remain readable.

A discount appears only when both amounts are valid and the discounted amount is positive and lower than the original. With no valid discount, the existing single price is displayed unchanged.

Existing records are not changed automatically. On saving and publishing a discount, the reduced amount remains the selling fare in `price`, while `originalPrice` stores the crossed-out comparison amount. Both survive reloading. Existing website booking calculations continue to use the selling fare; payment methods are unchanged. The current local Theyyam trip record contains only ₹5,999, so Price and Discounted Price must both be set to display the ₹6,599 / ₹5,999 example.

Clearing Discounted Price removes the offer and uses Price as the selling fare. To remove the crossed-out amount while retaining ₹5,999 as the fare, set Price to 5999 and clear Discounted Price.

A new manager installation is required. Existing signing and storage configurations are retained; do not uninstall the current Android app to work around a signing error without first preserving local drafts/settings.