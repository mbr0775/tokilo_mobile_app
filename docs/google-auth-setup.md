# Google sign-in and account email setup for Tokilo

Updated 14 October 2026. Both Login and Signup use Supabase Google OAuth in the system browser. A successful callback restores a Supabase session, and the router opens the customer feed or administrator dashboard. Opening the browser alone is not successful sign-in. Signup's Google path requires acceptance of the existing terms without requiring email/password form fields.

## Google Auth Platform

Google Cloud project: `tokilomobileapp`. Web OAuth client: `Tokilo Supabase OAuth`.

Authorized Google redirect URI:

```text
https://nsosypdtxdoeiszilpwj.supabase.co/auth/v1/callback
```

The Web application's client ID and secret are saved directly in the Google provider settings of the shared Supabase project. A Gmail address is not a client ID. Never place Google's client secret in the app or repository. This integration uses browser OAuth, so it does not require an Android native OAuth client/SHA fingerprint; native Google account selection would use a different integration.

Google sign-in is enabled in Supabase. Skip nonce checks and allow-users-without-email are disabled. The app requests only basic identity scopes, email/profile. Google Cloud Audience and Overview pages repeatedly failed to load after setup, so production publishing/branding status remains unverified. Basic identity scopes are exempt from Google's test-user allowlist; this does not itself verify branding or publishing approval.

## Supabase production URLs

Project: `nsosypdtxdoeiszilpwj`, shared by the website and mobile app.

Site URL: `https://www.tokilotech.com`.

Release callback:

```text
com.tokilotechnologies.businesshub://login-callback
```

The Android release package is `com.tokilotechnologies.businesshub`. Android and iOS URL schemes are configured to use this callback. Supabase's redirect allowlist contains it, the signup-only `com.tokilotechnologies.businesshub://email-confirmed` callback and the earlier debug callback `com.tokilo.app://login-callback`. Google's HTTPS callback belongs in Google Cloud; the mobile custom scheme belongs in Supabase. Web builds use the current web origin and need a matching allowed redirect.

## Confirmation and password-reset mail

Resend account uses the verified `accounts.tokilotech.com` domain in Tokyo, with DKIM and sending CNAME records added in Hostinger. Existing Lankar `auth.tokilotech.com` records were preserved.

Supabase custom SMTP is enabled with host `smtp.resend.com`, TLS port `465`, username `resend`, sender `no-reply@accounts.tokilotech.com`, display name Tokilo Business Hub and minimum per-user interval 60 seconds. A sending-only Resend key restricted to that subdomain is saved in Supabase. No SMTP password is stored in this repository.

Version 2 separates email confirmation from Google/recovery callbacks. Email signup uses `com.tokilotechnologies.businesshub://email-confirmed`: Supabase verifies the email before redirecting, and the app returns to Login without exchanging that code for an automatic session. Google and recovery use `login-callback` with the Supabase PKCE exchange. After a successful password update the app clears the temporary session and encrypted persisted session, then returns to Login. A failed update stays on Reset and does not claim completion. ResetPasswordScreen requires a valid recovery session, validates password length and matching confirmation, and reports success only after Supabase acknowledges the update. Invalid/expired callback errors are shown through the app's global message handler. Encrypted platform storage protects sessions and PKCE verifiers; backup is disabled for release Android data.

## Recorded validation

- On 13 October, the owner completed Google sign-in on Samsung SM-S721B using the older debug callback. The authorization endpoint returned the correct Google redirect and basic identity scopes, and aggregate database checks confirmed a Google identity/sign-in. Nine OAuth/startup regression tests passed in that configuration pass.
- On 14 October, the owner confirmed Google sign-in returned to the signed release on the connected NIC-LX2. Home, Feed and admin/client navigation loaded real records. Encrypted session storage persisted across a force-stop/cold restart and APK update.
- All 51 Flutter tests passed; four password-recovery tests were repeated after final copy changes. A real reset request from the installed release was accepted and Resend recorded delivery to the owner's email.
- The owner completed reset in Tokilo and confirmed login with the new password. A fresh device capture showed the signed-in Feed after completion. No password was read or stored by the agent.
- Version 2 completion-routing tests cover signup, immediate signup sessions, email confirmation, recovery success/failure, encrypted-storage clearing, expired callbacks and Google sign-in. The owner completed the installed version 2 email-confirmation flow and verified it ends at Login. Password reset also ended at Login and the new password successfully signed in.
- iOS compilation/device validation still requires macOS/Xcode. Google Audience/branding production publishing has not been verified.

## Regression checklist

1. Run `flutter test` and build the signed release with private local signing configuration.
2. Tap Continue with Google, choose an allowed account and verify return to Feed or Dashboard.
3. Repeat from Signup after accepting terms, leaving email/password fields empty.
4. Cancel Google's browser flow and verify retry remains available.
5. Restart after successful sign-in and verify session persistence.
6. Request reset through the installed app, open the delivered email on the same device, complete the password change yourself, verify the app returns to Login, then test password login. Repeat signup with a new email and verify its confirmation also returns to Login.
7. Request a new link after an expired/used link; ensure failure never displays successful reset.

References: [Supabase Google sign-in](https://supabase.com/docs/guides/auth/social-login/auth-google), [Flutter OAuth/deep links](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/README.md), [Google OAuth app states](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview), [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp).
