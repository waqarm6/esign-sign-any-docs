# eSign Doc Pro — Current Handoff

## Working location

The project is now in the persistent Codex workspace at:

`C:\Users\uzair\Documents\Codex\2026-09-26\workspace-scratch-esigndocpro\eSignDocPro`

## Cross-platform requirement

Every new feature and UI change must support both Android and iOS. Keep platform-specific behavior behind the shared Flutter service interface, and verify Android without breaking the existing iOS implementation.

## Starting point reviewed

- Flutter UI foundation is present.
- Onboarding, home, document library, signing workspace, signature drawing, and paywall surfaces are implemented.
- iOS VisionKit scanning and document import bridges are present.
- Android and iOS scanning use the in-app `paper_document_scanner` flow with live camera preview, edge detection, auto-capture, manual shutter, corner adjustment, and multi-page support.
- Flutter SDK is available at `C:\flutter` and the Android SDK is available at `C:\Users\uzair\AppData\Local\Android\sdk`.

## Work completed in this continuation

- Android imports now copy the selected PDF/image into the app cache and return a local path instead of a transient content URI.
- Imported/scanned source paths are retained on the local draft record.
- Flutter platform-channel errors now resolve as a cancelled/unavailable selection instead of throwing into the UI.
- Flutter Android/iOS scaffolding was generated with `flutter create` using the eSignDocPro package identity.
- Pescalow-specific Firebase, maps, signing, and service configuration was not copied into this document app.
- Android scanner/import bridge is now attached to the generated `com.esigndocpro.esign_doc_pro` activity package.
- Android local SDK paths are recorded in `android/local.properties` for this machine.
- The arm64 debug APK now builds successfully with compile SDK 36 and is available at `build/app/outputs/flutter-apk/app-debug.apk`.
- The camera capture update was rebuilt and installed successfully on `SM A075F` over wireless debugging.
- The Android scan path was moved away from the custom activity-result bridge after device logs showed duplicate result replies; the maintained camera picker was tested through the permission prompt into Samsung Camera without a crash.
- The scanner was then upgraded to the in-app cross-platform scanner; on Android the live preview, manual shutter, captured-page review, and finish controls were verified on `SM A075F`.
- Auto mode is enabled explicitly with live detection at 15 fps, a green detected-edge overlay, and a relaxed stable-capture threshold; the scanner control is labeled `Auto capture`.
- The scanner now includes a fixed white document guide frame and alignment prompt; detected edges remain green and captured pages open directly into edge adjustment before keeping.
- The guide frame was enlarged and made portrait-oriented to better fit full-page documents while leaving the shutter controls accessible.
- The guide now uses sharp corner brackets only, so the live green detected-edge overlay stays visible instead of being covered by a rounded border.
- If edge detection fails on a manual capture, the returned image now falls back to cropping inside the guide area instead of returning the entire camera frame; detected or manually adjusted corners still take priority.
- Image captures and imported images now render as the actual source page in the signing workspace, and saved document entries reopen their source path. PDF page rendering remains the next preview step.
- Signature drawing now repaints reliably during pointer movement, uses rounded quadratic smoothing, and supports cancellation without leaving a stuck stroke.
- Saved signatures now persist their actual stroke points locally and the signing workspace renders the real drawn ink instead of the placeholder "Signature" label; the placed signature remains movable and scalable.
- The updated arm64 debug APK was built and installed/launched over USB on `SM A075F`.
- Signature placement now uses transparent ink over the document: the white card fill was removed, and only a temporary outline/handle is shown while the signature is selected. Tapping it hides the editing chrome so the document remains visible underneath.
- Reviewed current Acrobat, DocuSign, and SignNow signing patterns: draw/import/capture, place by tap, move, resize, delete before final save, and preserve transparent signature artwork over the document.
- Added professional signature controls in the shared Flutter flow: reusable saved strokes, ink color palette, thickness slider, undo, clear, and long-press replace/delete actions. Stroke color and width are persisted with the transparent signature.
- Text now opens a real editor and can be tapped again to edit; date opens a date picker; checkboxes toggle; stamps offer Approved, Paid, Review, and Rejected choices. All placed overlays use transparent backgrounds so the source document remains visible.
- The latest APK was built, installed, and launched successfully on `SM A075F` over USB.
- The editor now tracks one selected annotation at a time; inactive fields show transparent content without editing borders, while selected fields show a move/resize affordance.
- All placed fields now support shared drag, pinch scale, and two-finger rotation behavior: text, date, checkbox, stamp, markup, and signature.
- The signature screen now shows a saved-signature card with Use, Edit, and Add new actions. Existing signature strokes load without forcing a redraw, and changing ink color or thickness updates the existing signature live. Undo, clear, replace, and delete actions are available.
- The updated APK was visually checked on `SM A075F`: saved signature card displayed correctly and changing the brush color updated the existing signature immediately.
- Markup was removed from the editor tool row and annotation model. Selected small fields now receive a larger stable, unscaled touch surface so text, date, checkbox, and stamps can be pinched smaller as well as larger without shrinking their gesture target.
- Stamp creation now includes preset transparent outlined stamps plus a custom transparent-stamp wording flow. Custom stamp wording is editable and can be recolored, resized, rotated, and repositioned like the other fields.
- Fixed the Text tool red-screen assertion that occurred when typing into the modal editor by moving text entry into a dedicated route with an owned controller/focus lifecycle. On-device verification completed: opened Text, typed `Hello test`, tapped Done, and confirmed the transparent text overlay was placed without `Failed assertion` or crash.
- Added explicit, touch-sized rotate and resize handles to every selected annotation, including the custom transparent signature overlay. The existing pinch/drag gesture support remains available for Android and iOS.
- Added a selected-annotation toolbar with smaller/larger, rotate left/right, style, and delete actions. Text and date expose live color and font-size controls; checkbox and stamp expose color controls; markup exposes color and opacity controls. Signature styling continues through the live brush editor.
- Built and installed the updated arm64 debug APK on `SM A075F` over USB. On-device verification confirmed a text field resized from its handle, rotated from its handle, and opened the style sheet with live color and size controls.
- Smoothed shared drag/pinch/rotate gestures by anchoring each interaction to its starting position, focal point, scale, and rotation instead of accumulating against a moving widget position. Added repaint boundaries around the document image and annotation artwork so transforms do not repaint the full page on every pointer frame.
- The smooth-gesture source change passes `flutter analyze`. A fresh APK rebuild was attempted, but the C: drive ran out of space while regenerating the Android/Gradle native cache; the previously installed APK remains on the phone and does not yet contain this final smoothness pass.
- On 2026-09-27 another isolated, low-footprint rebuild was attempted. It was stopped after C: fell from about 6.3 GB to about 3.6 GB free without producing an APK, then generated build artifacts were cleaned back to about 5.4 GB free. The connected device was not visible to ADB afterward, so the final smoothness pass has not been installed or device-verified yet. No Pescalow source or cache was used or modified.
- On 2026-09-28 the wireless phone was rediscovered as `SM A075F`, and an explicit `GRADLE_USER_HOME` build path was used for eSignDocPro. One direct diagnostic invocation was stopped after following the machine's existing `C:\Users\uzair\.gradle` junction into the Pescalow Gradle cache; it hit the full-disk condition and was terminated. No Pescalow source was edited. Subsequent isolated builds were stopped before C: reached zero, and their generated eSignDocPro output was cleaned. The final smoothness APK is still not built or installed.
- The user-authorized Ace Luxe backup ZIP `C:\Users\uzair\Documents\Codex\2026-08-17\w\backups\ace-luxe-theme-before-pms-20260905-045305.zip` was deleted to recover space. A single-worker isolated rebuild was retried afterward but still approached the disk limit before producing an APK; generated output was cleaned again. C: currently has about 4.3 GB free.
- On 2026-09-29 wireless debugging rediscovered `SM A075F` at `192.168.1.6:43017`. The previously installed eSignDocPro APK launched successfully to the scanner screen; no `FATAL EXCEPTION` or `AndroidRuntime` entries were found in the recent log. The final smooth-gesture source changes are still not in an installed APK.
- Added a 24 px transparent gesture hit margin around every movable field. Small text, date, and checkbox overlays keep their visible bounds and document position but now have enough touch area for reliable two-finger pinch, drag, and rotation. `dart format` completed and `flutter analyze` reports no errors; only the existing style/deprecation notices remain.
- Reworked transform behavior again after on-device review: pinch scale and rotation are now anchored to the true gesture focal point, so fields do not drift around their top-left corner. Live transform frames for text, date, checkbox, stamp, markup, and signature stay local to the movable widget and commit to the document state on gesture end, reducing full-page rebuilds and improving frame smoothness. `flutter analyze` still reports no errors. A new APK has not yet been built because C: remains below the required native build headroom.
- On 2026-09-29 the transform hit target was corrected so its touch padding stays unscaled. This keeps a stable two-finger grab area after an annotation has been reduced, allowing pinch-to-shrink as well as pinch-to-grow on Android and iOS.
- The corrected arm64 debug APK was built on the isolated D: staging checkout at `D:\eSignDocPro-build` using `D:\eSignDocPro-gradle` and `D:\eSignDocPro-pub-cache`; no Pescalow source or cache was used. It was installed over wireless debugging on `SM A075F` at `192.168.1.24:40557` and launched successfully with no recent fatal Android crash entries.
- Markup was removed from the editor tool row and annotation model. Selected small fields now receive a larger stable, unscaled touch surface so text, date, checkbox, and stamps can be pinched smaller as well as larger without shrinking their gesture target.
- Stamp creation now includes preset transparent outlined stamps plus a custom transparent-stamp wording flow. Custom stamp wording is editable and can be recolored, resized, rotated, and repositioned like the other fields.
- The latest D: APK was installed and cold-launched successfully on `SM A075F` over wireless debugging at `192.168.1.29:46503`; package update time confirmed the new installation and no fatal Android log entries were reported.
- Stamp custom creation now accepts transparent PNG/WebP image uploads through the shared Flutter file picker. The uploaded artwork is rendered without a background and remains adjustable with the existing move, pinch, rotate, and resize gestures on Android and iOS.
- Added `google_fonts` 8.2.1, compatible with the project’s Dart 3.12.2 SDK. Text, date, and preset text-stamp annotations can select from Inter, Roboto, Open Sans, Lato, Montserrat, Poppins, Raleway, Merriweather, Playfair Display, Roboto Slab, Oswald, and Caveat through the shared style panel.
- The combined stamp-image and font-selection arm64 debug APK was built on D: and installed/launched on `SM A075F` over wireless debugging at `192.168.1.29:46503` on 2026-09-29; no recent fatal Android crash entries were reported.
- Draft persistence is now implemented in the shared Flutter document model. Draft records store the source path plus the placed signature strokes, text, date, checkbox, preset/custom stamp, image-stamp path, positions, scale, rotation, colors, font choices, and values.
- Leaving the workspace through the close button, Save draft, app backgrounding, or the system back flow preserves the current document as a local draft. Reopening a draft restores the annotation state for continued editing.
- The Documents screen now has separate Drafts and Completed tabs, and the Home count cards open the corresponding filtered tab. Drafts are available without a subscription.
- Export/share remains behind the entitlement sheet. When the trial or subscription flow reports success, the current record is promoted to Completed and remains editable from the Completed tab.
- Screenshot protection is enabled through `screen_security` after the first rendered frame and reinforced with Android `FLAG_SECURE` in `MainActivity`. The final protected build was installed on `SM A075F` at `192.168.1.29:46503`; an ADB screenshot produced a black/obscured capture while the app remained visible on the phone. iOS uses the plugin's best-effort secure rendering behavior and should be verified on a physical iPhone before release.
- The final draft-persistence arm64 debug APK was built from `D:\eSignDocPro-build` using isolated D: Gradle/Pub caches and installed/launched successfully on `SM A075F` on 2026-09-30. No Pescalow source or cache was used.
- Added explicit Flutter system-back interception around the signing workspace so Android back gestures and iOS back navigation save the current draft before leaving. The follow-up APK was rebuilt, installed, cold-launched, and screenshot-tested on `SM A075F`; the captured screen was fully black under the secure-window policy.
- Finished the dashboard navigation: Documents and Tools destinations now open from the bottom navigation, the Tools screen exposes saved signatures, stamp presets, and the font library, and the Saved fields dashboard row is no longer a dead tap.
- Finished the local document library actions: image thumbnails, modified dates, rename, and delete are available for both Drafts and Completed records.
- Added real first-page PDF preview using the shared `printing` raster API instead of the old PDF placeholder card. Scanner sessions now request the package's assembled multi-page PDF output when available, while preserving the existing Android/iOS live detection and page review flow.
- Added gated export/share generation: after entitlement success, the editor captures the rendered document plus transparent annotations into a PDF, saves it in the app documents directory, and opens the native share sheet. Drafts still remain available when the paywall is dismissed.
- Replaced Settings dead taps with working appearance toggle state, language information, subscription/paywall entry, restore-purchases request, privacy policy, and terms dialogs. Store product configuration still must be supplied for production stores.
- The final dashboard/library/PDF/export arm64 debug APK was built from D: with isolated caches and installed/launched on the wireless `SM A075F` endpoint `192.168.1.29:34301` on 2026-09-30. No recent fatal Android log entries were found, and the secure screenshot capture remained black.
- Added a compile-time debug-only export bypass for QA: the Debug APK skips the subscription sheet, marks the document Completed, generates the annotated PDF, saves it locally, and opens the native share sheet. `kDebugMode` keeps this path disabled in profile and release builds. The bypass APK was installed/launched on `SM A075F` at `192.168.1.29:34301` with package update time `2026-09-30 16:50:00`.
- Fixed the empty-export bug by removing screen-capture PDF generation. Export now reads the original scanned/imported image or every page of the source PDF, then composes the saved signature, text, date, checkbox, and stamp overlays into each PDF page. This avoids `FLAG_SECURE`/screen-security blank captures.
- Export now also invokes the native Save PDF picker with the generated bytes, keeps a private recovery copy, and then opens the share sheet. The updated debug APK was rebuilt from D: and installed on `SM A075F` at `192.168.1.29:34301`; the app launched without a fatal Android exception.
- Corrected PDF annotation alignment: export now maps fields to the actual contained source-page rectangle, including source aspect ratio, editor inset, letterboxing, and overlay padding. Text/date sizing uses the page's vertical scale so exported text does not become artificially heavy or oversized. The corrected debug APK was rebuilt and installed on `SM A075F` at `192.168.1.29:34301` on 2026-09-30 17:21; no fatal Android exception was found after launch.
- Replaced PDF text/date font substitution with transparent Flutter-rendered text layers using the selected Google font, color, and weight. This keeps exported text visually consistent with the editor instead of relying on a heavier built-in PDF font. The test APK was rebuilt and installed on `SM A075F` at `192.168.1.29:34301` at 17:32; the app launched with no fatal Android exception.
- Completed PDFs are now persisted with their generated internal PDF path. Export opens a swipeable in-app PDF viewer after the share flow, and the Completed library opens the saved PDF directly with page count, Share, and Edit actions. The debug APK was rebuilt and installed on `SM A075F` at `192.168.1.29:34301` at 17:46; no fatal Android exception was found after launch.
- Replaced the single Export & share action with a cross-platform action sheet offering `Share PDF` and `Export as PDF`. Share opens the native share sheet; Export opens only the save picker and then the in-app PDF viewer. The debug APK was rebuilt from D: and installed on `SM A075F` at wireless endpoint `192.168.1.29:45381` at 20:28; the app launched with no fatal Android exception.

## Next recommended work

1. Verify the Save PDF picker and shared PDF contents on the phone with a real scanned multi-page document and placed annotations.
2. Add production store product identifiers and verify the release/profile entitlement gate.
3. Replace placeholder store/legal copy and app imagery before release.

## Verification note

`flutter pub get` completes successfully. `flutter analyze` reports only style/deprecation notices. The latest APK was built and installed from D: with explicit isolated Gradle and Pub caches; do not point this project at the machine-level `.gradle` junction because it belongs to Pescalow. The installed package is `com.esigndocpro.esign_doc_pro`.
