# eSign Doc Pro — Product Specification

## Product goal

eSign Doc Pro is a professional, privacy-focused document utility for iPhone, iPad, and Android. Users can scan paper documents, import PDFs or images, add reusable signing fields, and export a finished document.

The product must feel like a calm business utility. It must not use AI branding, chat patterns, generated-content language, robots, sparkles, or playful illustrations.

## Design direction

- Quiet professional visual language
- Warm off-white surfaces
- Deep graphite/navy typography
- Restrained teal accent
- Thin borders and soft elevation
- Clear document hierarchy
- Large touch targets
- Responsive layouts for phones and tablets
- Light and dark mode planned from the beginning
- Native-feeling navigation on both iOS and Android

## First-launch onboarding

1. Welcome: sign documents in a few steps.
2. Scan: use the camera to create a clean digital document.
3. Privacy: work locally and export only when ready.
4. Final offer: Start your 3-day free trial.

The user may skip or dismiss the offer and continue using the app. The final offer must clearly state: “Then $6.99/week. Subscription renews automatically until cancelled.” Terms and Privacy links must be visible on the live paywall.

## Home screen

Primary actions:

- Scan Document
- Import File

Secondary areas:

- Drafts
- Completed Documents
- Create Signature
- Saved Fields and Tools

Supported initial inputs:

- Camera scan
- PDF import
- PNG import
- JPG import

## Scanner flow

1. Camera permission explanation.
2. Live document camera with edge guide.
3. Automatic capture and manual capture.
4. Edge adjustment and perspective correction.
5. Enhancement options: original, color, grayscale, black and white.
6. Multi-page scan session.
7. Page reorder, rotate, crop, and delete.
8. Continue to editor.

## Editor flow

Users can edit without subscribing:

- Add signature
- Add initials
- Add text
- Add date
- Add checkbox
- Add stamp
- Highlight
- Underline
- Freehand markup
- Move, resize, and remove placed elements

The draft is saved locally while the user works.

## Export gate

When the user taps Save, Export, Share, or Print, show the subscription offer if they are not subscribed. Editing remains available and the local draft must not be deleted.

The paywall should explain:

- Save signed PDFs and images
- Share completed documents
- Unlimited signing
- 3-day free trial
- $6.99/week after the trial
- Automatic renewal and cancellation information

## Documents

Drafts and completed documents are stored locally in the first release. Each item has a name, thumbnail, page count, created date, modified date, and status.

## Platform and engineering

- Flutter shared application layer
- iPhone and iPad layouts
- Android phone and tablet layouts
- Native scanner bridge where required
- Local-first document processing
- StoreKit auto-renewable subscription on Apple platforms
- Google Play Billing subscription on Android
- No account required for the first release
- No server required for the first release

## Delivery phases

1. UI foundation and design system — started.
2. Scanner and image pipeline.
3. PDF/image import and document workspace.
4. Editing tools and signature manager.
5. Local drafts and completed-document library.
6. Export paywall and subscription implementation.
7. Accessibility, performance, privacy, and store review QA.
