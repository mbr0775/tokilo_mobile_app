# Data safety draft for owner review

This draft follows the current source and shared backend. It is not a submitted Play declaration. Account for both app code and SDKs, including Firebase Installations included through FCM. Recheck against the exact uploaded build and live integrations.

## Proposed data categories

- Personal information: name, email, account user ID, optional phone/company information. Used for account management, authentication, requests and support. Google provides identity/profile information when chosen.
- Messages: private support messages and uploaded image attachments. Used for app functionality and customer support, visible to the customer and Tokilo administrators.
- Photos: images the customer intentionally selects through the system picker and uploads to support. Optional; the app does not request broad photo-library permission.
- Other user content: project request titles, descriptions and business notes. Optional to using account/project browsing; required when submitting a request.
- App activity: feed likes, online presence and notification read state. Used for app functionality; no advertising or marketing analytics SDK is included.
- Device or other IDs: Firebase installation identifiers and FCM registration tokens for notification delivery. Firebase also processes SDK user-agent/app metadata. Notification registration is optional and tied to the signed-in account.

Data is transmitted over HTTPS and retained in the shared Supabase backend while providing the service. Chat images use private storage and temporary signed URLs. Account information, support records and chat attachments are included in deletion. No precise location, contacts, SMS/call history, advertising ID, payment card data or health data is requested by this build.

## Providers and sharing decisions

Supabase processes auth/database/storage; Google provides sign-in; Firebase delivers push notifications; Resend delivers confirmation/reset emails and receives recipient addresses and delivery information. Review Google's service-provider exception before answering “shared”; do not declare “no data collected” merely because processors handle it. Support message contents are not included in the generic FCM preview. Review backend operational logs and retention as well as app code.

Do not claim independent security review, end-to-end encryption, instant deletion of provider backups, or a guaranteed retention deadline. None has been established.

## Deletion and access

Customer Profile contains Delete account with explicit confirmation. The server targets the authenticated user, clears associated data/storage, then deletes the Auth account; the app signs out only after a matching acknowledgement. A company administrator uses an assisted support/handover path to protect company assets. The publicly accessible deletion page explains how to request deletion without reinstalling.

The owner completed password reset/login. An approved disposable account passed the live deletion endpoint test, including request removal, private upload cleanup and rejection of new requests using the deleted account's old token. A dedicated customer's native deletion UI flow and Play review access remain to be checked. Play review needs a dedicated customer account and private instructions, not the administrator account.

Official interpretation: https://support.google.com/googleplay/android-developer/answer/10787469

Firebase SDK details: https://firebase.google.com/docs/android/play-data-disclosure
