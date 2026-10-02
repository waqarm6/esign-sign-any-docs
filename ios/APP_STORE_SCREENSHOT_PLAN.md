# App Store Screenshot Plan

App: **eSign : Sign Any Docs**  
Screenshot story: **Scan & Sign Documents**

## Screenshot set

Use the same visual system across every frame:

- Portrait iPhone screenshots with generous top and bottom safe-area space.
- One short headline, one supporting sentence, and one clear app state per frame.
- Brand palette: deep navy, electric blue, cyan, white, and soft neutral document surfaces.
- Use realistic but fictional documents only; never show personal information.
- Keep interactive controls visible enough to prove the feature, without covering the document.
- Use the supplied transparent signature icon/logo only where it improves brand recognition.

### 1. Scan & Sign Documents

Headline: **Scan & Sign Documents**

Supporting text: **Turn paper documents into signed digital files.**

Capture state:

- Show the document scanner camera pointed at a clean paper contract or form.
- Show the scanner frame aligned to the page edges.
- Show edge detection or the auto-capture state if available.
- Keep the scan subject large enough to understand immediately.

Primary message: scanning is fast, accurate, and leads directly to signing.

### 2. Import Any Document

Headline: **Import Any Document**

Supporting text: **Import your files and start editing instantly.**

Capture state:

- Show the iOS file picker with a fictional PDF/document selected.
- Show the document opening inside eSign : Sign Any Docs.
- Keep the imported document title generic, for example `Service Agreement.pdf`.
- Avoid showing a personal name, email, address, or private document content.

Primary message: users can start from existing files, not only camera scans.

### 3. Add Your Signature

Headline: **Add Your Signature**

Supporting text: **Create, place and resize your signature anywhere.**

Capture state:

- Show a document with the signature tool active.
- Show a realistic handwritten signature placed on a signature line.
- Keep resize/rotate handles visible but subtle.
- Show the signature as transparent ink, not as a white rectangle.

Primary message: signatures look natural and can be positioned precisely.

### 4. Annotate With Ease

Headline: **Annotate With Ease**

Supporting text: **Complete forms and add important details in seconds.**

Capture state:

- Show the annotation toolbar open above the document.
- Include visible examples of **Text · Date · Checkboxes** on the page.
- Use a short sample value such as `Approved`, `06/12/2026`, and one checked box.
- Keep each annotation large enough to read at App Store thumbnail size.

Primary message: form completion is quick, flexible, and easy to review.

### 5. Create Custom Stamps

Headline: **Create Custom Stamps**

Supporting text: **Create and place your own custom stamps.**

Capture state:

- Show a stamp picker or stamp editor with a transparent custom stamp.
- Show professional examples: **Approved**, **Signed**, and one custom user-created stamp.
- Place one stamp on the document so the result is immediately understandable.
- Use a restrained teal/navy stamp style; avoid cartoon or novelty graphics.

Primary message: users can build reusable, professional document marks.

### 6. Export Your Signed Document

Headline: **Export Your Signed Document**

Supporting text: **Finish your document and export it when you’re done.**

Capture state:

- Show a completed document containing a signature, text, date, checkbox, and stamp.
- Show the Export/Share action in the bottom action area.
- Make the finished page look clean and reviewable before export.
- Do not show a real share recipient or private filename.

Primary message: the final document is ready to export and share.

## Capture targets

Apple accepts 1–10 opaque `.png`, `.jpg`, or `.jpeg` screenshots per device localization. Capture the primary portrait set at **1290 × 2796** for the 6.9-inch iPhone target and verify the final files in App Store Connect. Apple documents the 6.5-inch fallback sizes separately; do not stretch screenshots manually between device families.

Recommended order: 1 → 2 → 3 → 4 → 5 → 6. If only five screenshots are used, combine **Create Custom Stamps** into the **Annotate With Ease** frame and keep **Export Your Signed Document** as the final frame.

## Final QA before upload

- No transparency in the screenshot files.
- No debug banners, test prices, StoreKit local labels, or emulator chrome.
- No personal documents, names, email addresses, or account information.
- Text remains readable in App Store Connect thumbnail previews.
- Every screenshot matches the shipped app build and current app name.
- Verify the purchase wall and three plan prices separately; do not use a screenshot that suggests a trial or price not configured in App Store Connect.
- Keep the same status-bar treatment and device frame style across the set.

Source: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)

## Generated assets

The current six-frame set is in `ios/store_screenshots/`:

1. `01_scan_and_sign.png`
2. `02_import_any_document.png`
3. `03_add_your_signature.png`
4. `04_annotate_with_ease.png`
5. `05_create_custom_stamps.png`
6. `06_export_signed_document.png`

These are marketing compositions for App Store review and still need a final visual comparison against the shipped iOS build before submission.
