# Owner Authentication Fixes — Implementation Tasks

Maps every AC in `spec.md` → implementation work, dependency-ordered.

## Task 1: Add "Forgot Password?" button to OwnerLoginScreen
- **Status**: pending
- **Priority**: high
- **Covers**: AC-1
- **Files to change**:
  - `lib/features/auth/presentation/owner_login_screen.dart`
- **What to do**:
  1. Insert an `Align(alignment: Alignment.centerRight)` between the `PasswordTextField` and the `Sign In` PrimaryButton — mirroring the position used in the (non-owner) `LoginScreen`.
  2. Button label `'Forgot Password?'` → `onPressed: () => context.pushNamed(RouteNames.forgotPassword)`.
  3. Keep label style consistent with the owner palette (primary color match `AppColors.primary`).
- **Test Requirements** (all `rule` unless otherwise noted):
  - TR-1a: Widget tree contains a `TextButton` with `'Forgot Password?'` text in the rendered screen.
  - TR-1b: Tap on the button in an integration/widget test or code inspection results in the same navigation call as the working non-owner login screen.
- **Completion Evidence** (to be added during implement): ___

## Task 2: Refactor OwnerAuthController to enforce OTP gate on both Google + username/password login paths
- **Status**: pending
- **Priority**: high
- **Depends on**: none (but logically, after T1 since both touch controller/screen layer; no shared edits to exact same lines so they can run concurrently with care).
- **Covers**: AC-2, AC-4, AC-5
- **Files to change**:
  - `lib/features/auth/controllers/owner_auth_controller.dart`
  - `lib/features/auth/owner_auth_state.dart` (if new state flags needed)
  - `lib/core/services/owner_service.dart`
- **What to do**:
  1. Review current state flags: `OwnerAuthState` probably has `isLoading`, `errorMessage`, `isLoginSuccess`, `isRegistrationStarted`, `isOtpSent`, `isOtpVerified`. It may need `loginNeedsOtp` / `otpLoginPending` boolean so the login listener knows NOT to go directly to dashboard on `isLoginSuccess` without OTP verified first. Alternatively (simpler), set `isOtpSent=true` after a successful idToken exchange (Google) or after signInWithRetries success (user/pass), and set `isLoginSuccess` **ONLY after** the subsequent OTP `verifyOtp()` 200 OK.
  2. Refactor `OwnerAuthController.login(username, password)`: instead of returning right after `loginOwner` → success, set `isLoading=true`, call `loginOwner`, if it fails → `errorMessage`. If it succeeds (Firebase idToken verified), call `requestOtp()` next, then navigate to OTP screen via `context.goNamed(RouteNames.verifyEmail)` and set `isOtpSent=true`. It must NOT set `isLoginSuccess=true` here.
  3. Refactor `OwnerAuthController.signInWithGoogle()`: same pattern — after `signInWithGoogle()` succeeds (idToken verified with backend), do NOT set `isLoginSuccess=true`. Instead, call `requestOtp()`, navigate to `RouteNames.verifyEmail`, set `isOtpSent=true`. If Google account email mismatch → generic failure string `"Access denied. Ensure you are using the authorized owner account."` (per AC-3).
  4. Refactor `OwnerAuthController.verifyOtp(code)`: after successful OTP verification from backend (200 OK), NOW set `isLoginSuccess=true` and also grab the existing `profile` from current state (or re-read it from owner repository), so the screen listener triggers `context.goNamed(dashboard)` / business setup correctly. If OTP fails → set `isOtpVerified=false`, propagate generic "Invalid or expired verification code." error; do NOT set isLoginSuccess.
  5. Ensure `OwnerAuthController.resendOtp()` + state flags `isOtpSent` still work correctly; this is already used by `OwnerVerifyEmailScreen`.
  6. Make sure `OwnerService.requestOtpCode()` passes the hardcoded owner email to `POST /auth/owner/request-otp` (it already does — verify and keep unchanged).
- **Test Requirements**:
  - TR-2a (rule): After a successful `loginOwner(username, password)` call inside the controller, `state.isLoginSuccess` must still be `false` — instead `state.isOtpSent=true` is set, and no dashboard navigation triggered until subsequent verifyOtp success.
  - TR-2b (rule): After a successful `signInWithGoogle()` controller call, `state.isLoginSuccess` must be `false`; OTP flow must have started.
  - TR-2c (rule): After `verifyOtp(validCode)` succeeds, `state.isLoginSuccess=true` is set (and `isOtpVerified=true` as before, so dashboard routing fires).
- **Completion Evidence**: ___

## Task 3: Adapt OwnerVerifyEmailScreen routing so valid OTP → dashboard when business already exists (instead of always business setup)
- **Status**: pending
- **Priority**: high
- **Depends on**: T2 (shares the controller state flags `isLoginSuccess`, `isOtpVerified`; no overlapping lines so T2 + T3 can be worked on same machine sequentially).
- **Covers**: AC-5, AC-6
- **Files to change**:
  - `lib/features/auth/presentation/owner_verify_email_screen.dart` (the `_onVerify` success branch)
  - Optionally `lib/features/auth/controllers/owner_auth_controller.dart` to expose a `bool get isOnboardingIncomplete` helper for deciding where to route.
- **What to do**:
  1. Today in `_onVerify`, OTP success → `goNamed(RouteNames.businessSetup)`. This is correct when the owner is new / business not onboarded.
  2. After controller sets `isLoginSuccess`, check whether an `OwnerProfile` is already saved in state / local repo with a completed business. Use one of:
     - If `OwnerProfile` has a `businessId` field that's non-null → go to dashboard.
     - Else if a business-setup step was not completed → go to business-setup (existing behavior).
     - Fallback for simplicity: prefer `RouteNames.dashboard` after login-path OTP; the dashboard screen guards itself anyway if business is missing and redirects.
  3. Easiest robust fix: After OTP success, if `state.profile != null && state.profile!.businessId != null` → `RouteNames.dashboard`, otherwise `RouteNames.businessSetup`. Alternatively, `goNamed(RouteNames.splash)` to let the app-wide auth guard decide where to land, which already handles onboarding state correctly.
  4. Keep the existing OTP-field UX behavior (6 separate boxes, digits-only, auto-advance, resend w/ cooldown) completely untouched — only change the success routing.
- **Test Requirements**:
  - TR-3a (rule): After verifyOtp succeeds with `profile.businessId != null`, listener or direct code navigates to `dashboard` rather than `businessSetup`.
  - TR-3b (rule): After verifyOtp succeeds with no business on file, falls back to existing businessSetup flow (or splash, depending on chosen fix).
- **Completion Evidence**: ___

## Task 4: OwnerService hardening for enumeration resistance + edge cases
- **Status**: pending
- **Priority**: medium
- **Depends on**: none
- **Covers**: AC-3 (Google failure string), AC-6 (OTP invalid/expired string)
- **Files to change**:
  - `lib/core/services/owner_service.dart`
- **What to do**:
  1. `signInWithGoogle()` returns the generic string `"Access denied. Ensure you are using the authorized owner account."` for ALL failure cases (including: sign-in cancelled, wrong google email, firebase auth exception, network error, server 5xx/4xx). Only the exact success path returns `Result.success`. No differing error messages.
  2. `loginOwner()` returns generic `"Invalid username or password."` for all failures (firebase auth user-not-found, wrong password, network, server 4xx/5xx). No differing error.
  3. `verifyOtp()` returns `"Invalid or expired verification code."` for all failures (wrong digits, expired, network, server error).
  4. `requestOtpCode()` and `resendOtpCode()`: since the backend already masks all calls with HTTP 200, the service returns success whenever server says 200 (which it will even for wrong emails — and the Flutter side just says "Code sent" which is already consistent with enumeration resistance).
- **Test Requirements**:
  - TR-4a (rule): For all three methods (`signInWithGoogle`, `loginOwner`, `verifyOtp`), failure messages match a single constant string — no exception details ever leak.
- **Completion Evidence**: ___

## Task 5: Backend tests — confirm existing OTP masking + 503 propagation (no new routes — only validate old ones w/ Jest)
- **Status**: pending
- **Priority**: high
- **Depends on**: none
- **Covers**: AC-7, AC-8, AC-10
- **Files to change**:
  - `backend/tests/auth.test.js` (add describe block for requestOwnerOtp + verifyOwnerOtp behavior)
  - `backend/tests/test-helpers.js` (if MockEmailService.sendOwnerOtp doesn't exist yet — add it with same shape as MockFirebaseService pattern we've already used)
  - `backend/tests/jest.setup.js` (no changes expected unless `OWNER_EMAIL` env isn't already set — already added previous spec cycle for forgot-password so likely already ok)
- **What to do**:
  1. Add a `sendOwnerOtp` spy on `MockEmailService`: `async sendOwnerOtp({ to, otpCode, expiresAt }) { push onto sent[]; }`, matching the real signature in `email.service.js`.
  2. Add Jest cases:
     - T5.A: `POST /api/auth/owner/request-otp { email: owner@test.local }` → returns 200 + generic message body, MockEmailService.sendOwnerOtp called exactly once with `to=owner@test.local`.
     - T5.B: `POST /api/auth/owner/request-otp { email: attacker@evil.local }` → returns 200 + same generic message body, sendOwnerOtp call count 0 (enumeration masking), `generatePasswordResetLink` count 0, etc.
     - T5.C: MockEmailService throws `AppError(statusCode: 503, code: 'EMAIL_UNAVAILABLE')` when `sendOwnerOtp` is called → endpoint responds with HTTP 503 + correct `error.code` propagated (NO masking).
     - T5.D: `POST /api/auth/owner/verify-otp { email: owner, otpCode: correctFromRepo }` → 200 OK with onboarding-complete response.
     - T5.E: `POST /api/auth/owner/verify-otp { email: owner, otpCode: wrong }` → HTTP 4xx with generic "Invalid verification code" message.
- **Test Requirements**:
  - TR-5a (rule): Jest test `backend/tests/auth.test.js` passes all 5 OTP cases.
  - TR-5b (rubric, 0-2): Test fidelity. `2`: both happy + both negative paths (masked email + 503) + verify paths run. `1`: only happy-path tested. `0`: no tests added. Threshold ≥ 1.
- **Completion Evidence**: ___

## Task 6: OwnerAuthController integration (manual smoke on device)
- **Status**: pending
- **Priority**: medium
- **Depends on**: T1, T2, T3, T4, T5 (end of all other tasks)
- **Covers**: AC-2, AC-9 (rubric)
- **Files to change**: none — execution only
- **What to do**:
  1. Start backend locally. Capture SMTP logs to find real OTP codes generated in dev.
  2. Run Flutter on emulator. Execute: user+pass sign-in → OTP screen appears → enter code from log → verify success → dashboard.
  3. Execute: Google sign-in with matching owner email → OTP screen appears → enter code from log → verify success → dashboard.
  4. Execute: wrong code → generic error snack shown, cooldown timer functional on resend button, 60s countdown works.
  5. Execute: non-matching Google email → generic error snack.
- **Test Requirements**:
  - TR-6a (rubric, 0-2): Workflow UX quality per AC-9. `2`: no papercuts, smooth. `1`: functional with one papercut. Threshold ≥ 1.
- **Completion Evidence**: ___
