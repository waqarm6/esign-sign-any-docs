# eSign : Sign Any Docs — iOS release checklist

## Xcode and signing

- Open `ios/Runner.xcworkspace` on a Mac with the current stable Xcode.
- Select the Apple Developer team and confirm the registered bundle ID is exactly `com.esign.signanydocs`.
- Keep the deployment target at iOS 15.0 or newer.
- Run on a physical iPhone, then archive with the Release configuration.
- Validate the archive in Organizer before uploading to App Store Connect.

## App Store Connect subscription

- Sign the Paid Applications Agreement and finish banking and tax setup.
- Create one auto-renewable subscription group named `eSign : Sign Any Docs Premium`.
- Create product IDs `esign_doc_pro_weekly`, `esign_doc_pro_monthly`, and `esign_doc_pro_yearly` with one-week, one-month, and one-year durations.
- Set prices to $2.99 weekly, $7.99 monthly, and $49.99 yearly, with the 3-day introductory offer on each plan.
- Add an introductory offer: Free Trial, 3 Days, eligible for new subscribers.
- Submit the subscription with the app version and attach the required review screenshot.
- Add a Sandbox tester and verify purchase, cancellation, expiration, billing retry, and Restore Purchases.
- Consider enabling Billing Grace Period and App Store Server Notifications for production lifecycle handling.

The checked-in `Runner/eSignDocPro.storekit` file mirrors all three products and the 3-day trial for local Xcode testing. It does not create the real App Store products.

## App metadata and legal

- Supply a public Privacy Policy URL in App Store Connect. This is still required even though documents are processed locally.
- Supply a Support URL and marketing URL if used.
- Confirm the final app name, subtitle, category, age rating, keywords, description, screenshots, and review notes.
- Keep Terms of Use and Privacy Policy accessible in the app and on the paywall.
- Confirm the app privacy questionnaire accurately states any analytics, diagnostics, purchase, or tracking data used in the final build.

## Functional release tests

- Complete onboarding, dismiss the paywall, and verify drafts remain available.
- Verify eligible users see `Start 3-day free trial`; ineligible users see the selected plan’s subscribe action.
- Verify the localized prices and renewal disclosures match the App Store purchase sheet for all three plans.
- Verify an active subscriber bypasses the launch paywall.
- Verify Restore Purchases unlocks an active subscription and restored access survives relaunch.
- Verify Manage Subscription opens the Apple subscription management page.
- Test scan, import, annotation, draft persistence, PDF export, share sheet, and document preview.
- Test camera denial, file-picker cancellation, purchase cancellation, offline launch, and StoreKit failure states.
- Verify release builds block screenshots/screen recording and debug builds remain capturable for QA.
- Test on a small iPhone, a modern notched iPhone, and iPad in every supported orientation.

## Final assets

- Confirm the 1024×1024 marketing icon has no transparency (currently verified).
- Replace or approve the launch artwork and all App Store screenshots before submission.
- Confirm every screenshot and preview uses production UI and contains no private documents.
