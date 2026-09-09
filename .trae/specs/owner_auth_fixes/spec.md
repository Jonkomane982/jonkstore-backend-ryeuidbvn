# Owner Authentication Fixes — Specification

## Problem & Context

Three user-facing defects in the Owner Access flow block JonkStore POS from being usable for the authorized owner:

1. **No "Forgot Password?" UI on the Owner Access login screen.** `OwnerLoginScreen` (the actual route at `/login` per `app_router.dart`) has no navigation to the forgot-password screen. The separate `LoginScreen` widget has the button, but it's not the screen users land on.
2. **Google Sign-In returns "Access denied" even when the owner selects their registered Google account.** Looking at `OwnerService.signInWithGoogle` + `AuthController.login`, the backend `POST /auth/login` already does the right check: it blocks non-owner emails with `OWNER_ACCOUNT_REQUIRED`. The failure in the screenshot suggests either:
   - the Google account picked doesn't match the `OWNER_EMAIL` env var, OR
   - after a fresh Firebase account is created via Google Sign-In, there's no explicit handling that gives the fresh owner user a route into the app (the backend creates a `user` row but doesn't tell the frontend whether it should go to dashboard vs onboarding vs OTP verification).
3. **Username + password flow never sends an OTP before granting dashboard access.** Currently `OwnerAuthController.login()` → `OwnerService.loginOwner()` → `signInOrCreateWithRetries` + `POST /auth/login` → proceeds to dashboard with NO second factor. But the "Owner Setup" screen description promises: *"A 6-digit verification code will be sent to the registered email"*. The user wants this 6-digit verification step applied to every username/password sign-in as an additional factor before they reach the dashboard.

### Users affected
- The single authorized owner (configured via `OWNER_EMAIL` env var + Firebase Admin) logging in from the Flutter POS app on Android.

### Goals
- Make Owner Login discoverable, secure, and matching the UI in the user's screenshots.
- Google Sign-In with a matching Google account → proceeds through OTP verification (if required) to the dashboard — NO access denied screen when it matches the owner email.
- Username + password → server sends 6-digit OTP to owner email, user enters 6-digit code in an OTP input UI → server verifies → dashboard access granted.
- Enumeration resistance is preserved on all non-infrastructure paths.

### Non-Goals
- NOT adding multi-user/staff login. Only the single configured owner email works; all others are masked or denied.
- NOT changing the `LoginScreen` widget that isn't wired to any route (it's unused; we fix `OwnerLoginScreen` directly).
- NOT sending OTP codes to any email other than the single `OWNER_EMAIL` configured in `environment.ownerEmail`.
- NOT implementing WebAuthn / passkeys / TOTP-app authenticators. Email-delivered 6-digit numeric OTP only.

---

## Functional Requirements

### FR-1. Owner Login Screen navigation
- FR-1.1 `OwnerLoginScreen` (the route at `/login`) MUST display a "Forgot Password?" tappable button that navigates to `RouteNames.forgotPassword` (`/forgot-password`).
- FR-1.2 For consistency with screenshot 1, the existing username/password labels ("Username"/"Password"/"Sign In") and Google button ("Continue with Google") MUST remain.
- FR-1.3 The "Create Owner Account" secondary call-to-action MUST remain below the Google button (users entering with wrong credential state still need to reach onboarding).

### FR-2. Google Sign-In with matched owner email = successful OTP-gated login
- FR-2.1 When the Flutter `GoogleSignIn` account selector returns an email that matches `AppOwner.ownerEmail` (case-insensitive), the sign-in flow MUST NOT throw the generic "Access denied…" failure.
- FR-2.2 Instead, immediately after successful Google Sign-In token verification against `/api/auth/login`, the Flutter app MUST request an OTP from `POST /api/auth/owner/request-otp` with the owner email, navigate to `OwnerVerifyEmailScreen`, present a 6-digit input box, call `POST /api/auth/owner/verify-otp` with the user's digits, and on `200 OK` proceed to:
  - Dashboard when an OwnerProfile / Business already exists;
  - Business setup otherwise (matches existing `stateAfter.isOtpVerified → businessSetup` routing in register flow).
- FR-2.3 If the Google-selected email does NOT match the owner email, the Flutter app MUST return a generic auth failure (enumeration resistance). It MUST NOT distinguish between "wrong account" and "network error" from the UI.

### FR-3. Username + Password sign-in = 6-digit email OTP gate
- FR-3.1 Submitting username + password from `OwnerLoginScreen` MUST:
  1. Validate the username/password combination server-authoritatively.
  2. On success: send a 6-digit numeric OTP to the single registered owner email via SMTP (or 503 in prod if SMTP isn't configured; never fake success).
  3. Navigate the UI to an OTP entry screen with 6 individual digit inputs.
  4. On correct OTP submission → navigate to dashboard (or business setup if business not yet onboarded).
  5. On incorrect / expired OTP → generic error message "Invalid or expired verification code."; resend button with 60-second cooldown.
- FR-3.2 The 6-digit OTP MUST be verified server-authoritatively against the DB `owner_otps` table by `POST /api/auth/owner/verify-otp`. It cannot be validated in-app.
- FR-3.3 OTPs must be 6 numeric digits (no letters), expiring 15 minutes after generation. Same rules already enforced by backend OTP repo.
- FR-3.4 On username/password mismatch, error message MUST remain generic ("Invalid username or password."). No username enumeration.

### FR-4. OTP screen shared by Google flow + Username/password flow
- FR-4.1 The existing `OwnerVerifyEmailScreen` widget MAY be reused for both flows. If it navigates to business setup after verification, the behavior MUST be adapted so:
  - If the owner already has a completed profile → dashboard.
  - If the owner is new / incomplete onboarding → business setup.
- FR-4.2 The OTP screen MUST provide resend behavior with cooldown (60 seconds) and a Back button.
- FR-4.3 The OTP input MUST be restricted to digits only (no letters/whitespace), auto-advance between 6 boxes, auto-submit-friendly on 6th digit.

### FR-5. Server-only gate for all login finalization paths
- FR-5.1 A client cannot reach the dashboard by skipping the OTP step. Dashboard entry REQUIRES that:
  - Google flow: username/password was checked AND OTP verified successfully, OR
  - Username/password flow: same.
- FR-5.2 The server MUST NOT expose a route that issues an auth session/granted profile without having verified that an OTP was used for username/password login. Since the backend currently trusts Firebase idToken alone, we need a new server-side signal for "the current login session just completed an OTP verification step", OR keep the OTP check fully in the Flutter app's state machine as a mandatory step. We choose the Flutter-state-machine approach with an explicit "this login path requires OTP" flag in controller state.
- FR-5.3 For Google Sign-In with a matching owner email, the OTP is considered mandatory because the requirement states "after user has entered credentials → send code". For backwards compatibility, we keep this rule even for Google (it's a 2FA enforcement step).

## Non-Functional Requirements (NFR)

### NFR-1. Security
- NFR-1.1 No OTP code, reset token, or idToken is printed in application logs at INFO level or above on the backend (existing masking must remain).
- NFR-1.2 No new enum: all user errors (bad owner email, wrong OTP, invalid username/password combination) collapse to generic messages. Infrastructure errors return 5xx.
- NFR-1.3 OTP routes (`request-otp`, `verify-otp`) MUST be covered by the existing global rate-limit middleware.
- NFR-1.4 `POST /auth/owner/verify-otp` must be idempotent: marking a single OTP row used returns success only on first use; subsequent repeats return "Invalid or expired" (already enforced by `markAsUsed`).

### NFR-2. Production readiness
- NFR-2.1 If SMTP/Firebase Admin is unavailable in production, all server-side email generation endpoints MUST return 503 `EMAIL_UNAVAILABLE` / Firebase `SERVICE_UNAVAILABLE`. They MUST NOT return HTTP 200 with a "sent" message (no faking).
- NFR-2.2 On the Flutter app, all failure cases collapse to single generic failure strings that don't leak which step failed.

### NFR-3. UX
- NFR-3.1 Loading indicator shown during network calls on all buttons.
- NFR-3.2 Cooldown shown on resend button in `mm:ss` or countdown seconds.
- NFR-3.3 Invalid codes clear all OTP inputs and re-focus first box for fast retries.

### NFR-4. Compatibility
- NFR-4.1 Existing `requestOwnerOtp` / `verifyOwnerOtp` routes remain unchanged — they're already correct.
- NFR-4.2 Existing `/api/auth/login` idToken exchange route remains unchanged.

---

## Assumptions & Dependencies

- `AppOwner.ownerEmail` (the compile-time `OWNER_EMAIL` in Flutter) always matches the server-side `environment.ownerEmail`. If they diverge, the app won't submit the correct email to the backend when requesting OTPs — we'll use what the server-side knows (owner email constant) rather than trusting any client-sent value on identity-critical calls.
- Render environment variables `SMTP_HOST/PORT/USER/PASS/FROM` are required for real emails in production. Dev captures emails via the existing `email.service.js` dev-capture mode.
- Flutter GoogleSignIn scopes are correctly configured & Firebase project has Google sign-in method enabled. The Flutter side uses the existing sign-in logic, which already works when the account matches.
- OTP table `owner_otps` already exists via migrations in the Node DB schema.

## Open Questions (none — all decisions made from user screenshots)

---

## Acceptance Criteria (AC)

All ACs are typed as `rule` or `rubric` per Spec Mode rules.

| ID | Type | Criterion | Pass condition / Score anchors |
|----|------|-----------|-----------------|
| AC-1 | rule | Owner Login screen has visible, tappable "Forgot Password?" navigation → `/forgot-password`. | Tapping the button from `/login` pushes to `OwnerForgotPasswordScreen` on a running emulator; widget tree contains a "Forgot Password" button in `OwnerLoginScreen`. |
| AC-2 | rule | Google Sign-In success → OTP screen appears, 6-digit UI with digits-only input is presented. | After selecting a Google account that matches owner email in a debug run, the next widget in the tree is `OwnerVerifyEmailScreen` with 6 OTP fields. |
| AC-3 | rule | Google Sign-In non-matching email → generic error message only, no differentiation. | With a non-owner email picked, `next.errorMessage` in the controller equals `"Access denied. Ensure you are using the authorized owner account."` (same failure string used in other identity paths). Dashboard route NOT entered. |
| AC-4 | rule | Username + password sign-in: on valid creds → OTP email sent (or 503 EMAIL_UNAVAILABLE thrown in prod if SMTP down). No direct dashboard jump. | After valid username/password, controller does NOT set `isLoginSuccess=true`. Instead sets `isOtpSent=true` + navigates to OTP screen. Invalid creds → error only. |
| AC-5 | rule | OTP verification success on either flow → dashboard or business setup reached. | After submitting a server-marked-valid code, navigator either `goNamed(dashboard)` or `goNamed(businessSetup)` depending on profile existence. |
| AC-6 | rule | OTP verify with wrong/expired code → generic "Invalid or expired verification code." snack. | No "X digits wrong", no "expired 2 min ago" — only the generic string. |
| AC-7 | rule | Enumeration resistance preserved for `request-otp`. | `POST /api/auth/owner/request-otp {email: any}` always returns 200 + generic body, with SMTP only called when `email === ownerEmail`. Jest test asserting the call count. |
| AC-8 | rule | SMTP unavailable in prod → `sendOwnerOtp` propagates a 502/503 error (NOT masked as success). | Jest test: MockEmailService throws AppError(503) on send → endpoint responds 503, response body `error.code === 'EMAIL_UNAVAILABLE'` (or equivalent). |
| AC-9 | rubric | Workflow UX quality (0-2). | `2`: smooth → no state inconsistencies, cooldown timer visible, snackbars color-correct on success/error. `1`: functional but one UX papercut (e.g., no auto-advance). `0`: breaks or confusing state. Threshold ≥ 1. |
| AC-10 | rubric | Backend change test coverage & fidelity (0-2). | `2`: all new/modified controller branches exercised by Jest (valid OTP path, invalid cred path, SMTP down, wrong OTP). `1`: happy + 1 negative path tested. `0`: no tests. Threshold ≥ 1. |
