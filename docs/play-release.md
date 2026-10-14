# Tokilo Business Hub Android release

Prepared 14 October 2026. This document records verified work and remaining release gates; it does not certify Google Play approval.

## Release identity and artifacts

- Package: `com.tokilotechnologies.businesshub`; display name: Tokilo Business Hub.
- Flutter 3.41.6 / Dart 3.11.4; Android target and compile SDK 36.
- Play currently has AAB version 1.0.0, base version code 2, active and available to internal testers (14 October 2026, dashboard time 1:43 PM). The replacement candidate is 1.0.0+2. The owner confirmed email verification returns to Login and password reset returns to Login with the new password working on the installed version 2.
- Device APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`; version 2 split APK version code 2002 is Flutter's ABI offset.
- Upload certificate: `docs/release/upload-certificate.pem`. The upload private key and passwords are outside Git, under the owner's private Codex directory. Back them up securely before uploading.
- `android/key.properties` is local and ignored. Release builds fail when private signing configuration is missing, instead of silently using a debug certificate.

Build with `flutter build appbundle --release`. Increase `pubspec.yaml` build number before a later Play update. Do not put signing passwords in a committed workflow. Play App Signing's distribution certificate may differ from the local upload certificate.

## Verified checks

- All 63 Flutter tests passed for version 2, including signup consent, narrow-screen/keyboard layout, parallax/reduced motion and completion routing. Ten isolated Edge Function tests passed for the unchanged backend.
- Flutter analysis passed with no errors or warnings; 282 existing informational style/deprecation findings remain.
- Signed release AAB and split APK built. Native ELF load alignment and APK ZIP alignment passed 16 KB checks. A physical 16 KB device has not been tested.
- Updated release installed on the owner-confirmed NIC-LX2. Google OAuth returned to the app; Home, Feed, Profile, account legal links and Notifications were inspected. Session persisted across a force-stop/cold restart and an APK update.
- Shared production Supabase: `nsosypdtxdoeiszilpwj`. Google OAuth and mobile recovery callback: `com.tokilotechnologies.businesshub://login-callback`.
- Site URL is `https://www.tokilotech.com`. Privacy, policy alias and deletion routes returned successfully in production.
- Resend sender domain `accounts.tokilotech.com` verified via Hostinger. Supabase SMTP uses TLS port 465, `smtp.resend.com`, sender `no-reply@accounts.tokilotech.com`, name Tokilo Business Hub. Credentials are saved in Supabase, not this repository.
- A real reset request through the installed app was accepted and Resend recorded delivery to the owner's account. The owner completed reset in Tokilo and confirmed subsequent login with the new password; the device returned to the signed-in Feed screen.
- An owner-approved disposable account completed the live deletion endpoint test: Auth account, request record and private orphan upload were removed; its old token could not recreate requests. This proves the live backend path. Customer deletion UI rendering/acknowledgement is covered by isolated Flutter tests; the owner's administrator uses the assisted handover path.
- Existing three public chat images were copied, SHA-256 verified, referenced through the private bucket, then removed from the public location. Aggregate live results: 0 legacy public files, 3 private files, 3 private message references; bucket public flag false. The maintenance endpoint was subsequently disabled.

## Store URLs

- Privacy policy: https://www.tokilotech.com/privacy-policy
- Requested policy shortcut: https://www.tokilotech.com/policy
- Account deletion resource: https://www.tokilotech.com/delete-account
- Terms: https://www.tokilotech.com/terms-and-conditions
- Support: the business contact shown on those pages.

## Testing tracks and remaining gates

The inspected Play account is Personal, Tokilo Technologies. After owner approval of the required declarations, Tokilo Business Hub was created as draft app `4976391028586565194`. Its signed AAB version 1 (1.0.0), target SDK 36, was uploaded and processed for internal testing. The dashboard explicitly requires 12 testers opted in continuously for 14 days; production is locked. The internal release is active and available to testers. The existing 12-person list “Apzo Life Closed Testers for Lankar 2” is selected and saved for Tokilo. Closed testing has not been configured or started; internal days do not count toward its requirement.

1. Version 2 internal rollout and owner-completed email/reset checks are complete. Reuse the existing tester list for closed testing.
2. Review Play App Signing's distribution certificate and the automated pre-launch report.
3. Provide a dedicated non-admin review account and private access instructions. Do not give a reviewer the owner's administrator account or publish passwords in source.
4. Reset/password-login and disposable-account backend deletion tests passed. Finish cross-device chat/image/push testing and a dedicated customer's native deletion UI flow. Never delete a real business account to prove a test.
5. Complete the store listing, screenshots without personal customer data, Data safety, app access, content rating, target audience, ads and any additional forms shown by Play.
6. Supply real testers. For affected personal accounts created after 13 November 2023, Google requires at least 12 continuously opted-in testers for 14 days before production access can be requested. Read the actual Tokilo dashboard; another app's production status does not establish an exemption. Internal testing alone does not fulfil this closed-test requirement.
7. Check Google OAuth Audience/branding publishing status. Earlier Cloud pages failed to load; only basic identity scopes are requested. Successful owner sign-in does not prove publishing approval.
8. Review the Play pre-launch report, ANRs/crashes, accessibility and feedback on phones/tablets before requesting production access. No actual Play review or production release has occurred.

## Suggested honest listing

Short description: “Explore Tokilo projects, request digital services and talk with our team.”

Full description: “Tokilo Business Hub connects you with Tokilo Technologies. Explore our published software projects and studio updates, review digital service pricing, submit a project request and follow its progress. Sign in with Google or email, talk privately with the Tokilo support team, share project images and receive account updates. Manage your profile and access privacy and account deletion options from the app.”

Business audience; free download; no advertising SDK. Confirm actual service availability and listing declarations with the owner. Project services can be paid engagements; free download does not mean all business services are free. No in-app purchase or payment processing is included in this build.

## Official requirements

- Target API: https://developer.android.com/google/play/requirements/target-sdk
- Testing: https://support.google.com/googleplay/android-developer/answer/14151465
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Firebase SDK disclosure: https://firebase.google.com/docs/android/play-data-disclosure
- Native page sizes: https://developer.android.com/guide/practices/page-sizes

## Signup version 2 interface

Signup uses a light responsive layout, a native 3D illustration and scroll-linked parallax. Motion sleeps offscreen and respects disabled animations/accessibility navigation. Consent has a 48-pixel checkbox target, a vertically aligned tappable label and separate accessible policy links. Both Google and email signup require consent. Back and Login actions work even when Signup was opened directly. Form content remains static and usable without animation. Narrow-screen, enlarged-text, keyboard, consent/link independence and repeated parallax tests are included.

The version 2 signed arm64 split APK (code 2002) was installed over code 2001 successfully. Native signup header/consent, scrolling and keyboard rendering were inspected; signing and 16 KB ZIP alignment passed. The previous encrypted session survived the update. The owner confirmed version 2 email confirmation finishes at Login, and reset finishes at Login with subsequent new-password login working. Version 2 was subsequently uploaded, validated and published to internal testing. Play shows it active and available to internal testers, with status Not reviewed. This is not a public production release. The earlier owner-completed version 1 reset returned to Feed; that does not validate the newly requested Login behavior.

Version 2 AAB SHA-256: `6D7F3BE4A6BE256973C359C5A7050C4E92E63DF9FEF8CBF7EF45CD5A879F2972`. All six 64-bit native libraries passed 16 KB ELF LOAD alignment. The final split APK passed 16 KB ZIP alignment and was installed successfully. Code CI passed for commit `e0007e6d79deb147a17d8a88515563c97ef6a2c4`.
