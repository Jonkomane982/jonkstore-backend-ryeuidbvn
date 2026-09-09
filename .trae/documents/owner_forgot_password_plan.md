# Owner Forgot Password Implementation Plan

## Repository Research

### Current Architecture
- **Backend (Node.js / Express)**: Auth routes live at `/api/auth/*`. Firebase Admin SDK is the source of truth for identity. SMTP email service with graceful degradation (dev captures, prod requires SMTP). Centralized error handler, Zod validators, Pino logger with requestIds.
- **Frontend (Flutter / Riverpod)**: `OwnerForgotPasswordScreen` exists, wired via GoRouter (`/forgot-password`). Login screen already has "Forgot Password?" → navigates to it. `OwnerAuthController.forgotPassword()` calls `OwnerService.sendPasswordResetEmail()`.
- **CRITICAL GAP — Current `OwnerService.sendPasswordResetEmail()` calls `FirebaseAuth.sendPasswordResetEmail()` client-side**. This bypasses the backend entirely:
  1. No security masking / account enumeration prevention (Flutter Firebase SDK throws distinct errors that can distinguish user-not-found vs network vs quota).
  2. No custom branded email template (uses Firebase default).
  3. No backend audit log or rate limit enforcement.
  4. Requires Firebase API key in the client (already true, but backend mediation is preferred).
- **Backend has ready-made primitives**:
  - [firebase.service.js](file:///c:/Users/Jonkomane/AndroidStudioProjects/JonkStore/backend/src/services/firebase.service.js#L186-L192) → `generatePasswordResetLink(email)` returns a deep link.
  - [email.service.js](file:///c:/Users/Jonkomane/AndroidStudioProjects/JonkStore/backend/src/services/email.service.js#L211-L234) → `sendPasswordResetEmail({ to, link })` sends branded HTML/text email via SMTP (or captures in dev).
  - Security masking pattern already established in [auth.controller.js:requestOwnerOtp](file:///c:/Users/Jonkomane/AndroidStudioProjects/JonkStore/backend/src/controllers/auth.controller.js#L73-L103) — return HTTP 200 + generic success regardless of email match to prevent enumeration.
- **Only the authorized owner email** (`environment.ownerEmail` from `OWNER_EMAIL` env var) can ever be the recipient. Any other email should silently succeed (masking).
- Database tables already exist for users + businesses; password reset link itself is fully handled by Firebase Admin (it embeds a secure oobCode in the URL and stores state in Firestore/Auth backend) — no new DB migrations needed for this feature.

### Constraints
- Per project_memory: **Strictly forbid mock data, fake auth, simulated latency.** Return `503 ServiceUnavailableError` for unavailable services (SMTP not configured / Firebase admin not initialized) instead of 4xx or 2xx fake success.
- Per project_memory: **Never expose OTPs / reset tokens in the UI or logs.** (The reset oobCode lives inside the emailed link — the response body only contains a generic "if authorized" message.)
- Per user_profile security: Forbid exposing sensitive temporary credentials to UI (we don't return link to client).
- Node has `bcrypt` but we don't need it — Firebase admin is setting the password.

## Files and Modules

### Node.js Backend (changes)
- `backend/src/routes/auth.routes.js` — add `POST /owner/forgot-password` (unauthenticated, public route).
- `backend/src/controllers/auth.controller.js` — add `requestOwnerPasswordReset` method. Masking: always 200. Only generate link + send email if `email.toLowerCase() === environment.ownerEmail`. Graceful 503 if Firebase/SMTP unavailable in prod.
- `backend/src/validators/common.validators.js` — add `ownerForgotPasswordSchema = z.object({ email: emailSchema })` (only one validator needed; reuse `emailSchema`).
- `backend/src/middleware/validation.middleware.js` — **read first** to confirm pattern, then apply a `validateBody(ownerForgotPasswordSchema)` call on the new route.
- `backend/tests/auth.test.js` — add test cases:
  1. Happy path (matches owner email) → returns 200 generic message + calls firebase + email service.
  2. Wrong/unauthorized email → returns 200 generic message, does NOT call email/firebase.
  3. Invalid email shape → 400 ValidationError.
  4. Firebase admin unavailable in prod → 503 (no masking — this is an infrastructure error the client can't recover from via retries against different input).
  5. SMTP unavailable in prod → 503.

### Flutter Frontend (changes)
- `lib/core/services/owner_service.dart` — replace `_firebaseAuth?.sendPasswordResetEmail(...)` with `_apiClient.post('/auth/owner/forgot-password', data: { 'email': email ?? AppOwner.ownerEmail })`. Continue returning `Result<void>`; use the same error-masking pattern (generic "Action failed." / "Authentication failed." messages) so enumeration attacks from in-app error code inspection don't work either.
- `lib/features/auth/presentation/owner_forgot_password_screen.dart` — review existing UI; likely NO visual changes needed (the state flags `isPasswordResetSent` and the "Check your email" success panel already work exactly as we want).
- `lib/features/auth/presentation/login_screen.dart` — already has the "Forgot Password?" `TextButton`; no changes.
- `lib/core/routing/app_router.dart` / `route_names.dart` — already registered; no changes.

## Implementation Steps (dependency order)

1. **Backend Validator + Route + Controller**
   a. Add `ownerForgotPasswordSchema` to `common.validators.js`.
   b. Check `validation.middleware.js` pattern.
   c. Add `requestOwnerPasswordReset` method in `AuthController` in `auth.controller.js` (mirrors `requestOwnerOtp`'s masking structure but calls `firebaseAdminService.generatePasswordResetLink()` + `emailService.sendPasswordResetEmail()`).
   d. Wire route in `buildAuthRouter()`: `router.post('/owner/forgot-password', validateBody(ownerForgotPasswordSchema), authController.requestOwnerPasswordReset)` (no `auth` middleware — this is pre-login).
   e. Run backend linter + health check.

2. **Backend Tests**
   a. Add 5 test cases in `tests/auth.test.js`: happy match, wrong email masks, invalid shape 400, firebase down → 503, smtp down → 503.
   b. Run Jest: `npm --prefix backend test tests/auth.test.js`.

3. **Flutter OwnerService swap**
   a. Rewrite `sendPasswordResetEmail` to POST to backend instead of Firebase client SDK.
   b. Run Flutter analyze: `flutter analyze lib/core/services/owner_service.dart`.

4. **Sanity / smoke run (optional)**
   a. If backend server is available, hit `POST /api/auth/owner/forgot-password` with both owner email and bogus email to verify masking behavior + dev-captured email log.

## Dependencies and Considerations
- No new npm/pub packages required. All primitives already exist.
- Firebase Admin SDK is an `optionalDependency`. If not initialized, `generatePasswordResetLink()` already throws `ServiceUnavailableError` (per code review of firebase.service.js). Controller must NOT catch-and-mask this — it should propagate to centralized error handler as HTTP 503.
- Similarly, `emailService.sendEmail()` already throws 502/503 for SMTP issues in prod. Controller should let these propagate (do NOT convert to 200 masking). Masking applies ONLY to "unauthorized email" input. Infrastructure errors are real errors and must surface as 5xx to avoid user confusion (they won't help enumerate emails).
- Firebase `generatePasswordResetLink` deep link goes to the Firebase auth default action URL or the custom `continueUrl` configured in the Firebase Console. For the POS app, the standard Firebase link opens the browser and lets the user set a new password; the Flutter app's owner login will then work with the new password. No need for a custom `continueUrl` unless a web portal exists (it doesn't per repo scan — so default behavior is correct).
- Rate limiting: existing global `rateLimit` in environment.js (15 min / 1000 req) covers this. For this single-owner app it's acceptable; we don't need a per-email stricter limiter.

## Validation
- `npm --prefix backend test tests/auth.test.js` passes all new + existing auth tests.
- `flutter analyze lib/core/services/owner_service.dart lib/features/auth/controllers/owner_auth_controller.dart` no new errors/warnings.
- `npm --prefix backend run lint` (or equivalent eslint) on modified files.
- `GetDiagnostics` for Dart files after edits.
- Manual smoke: start backend locally, curl the endpoint, confirm dev-captured email is logged with correct subject + link only when owner email is submitted.

## Risks
| Risk | Handling |
|------|----------|
| Controller mistakenly masks SMTP/Firebase 5xx errors, causing user to think "email sent" when it wasn't. | Explicit rule: only the `email !== ownerEmail` branch returns masked 200. Every other branch (firebase link generation, SMTP send) throws and bubbles to error handler as 5xx. Jest test cases (4) and (5) enforce this. |
| Frontend still leaks enumeration via distinct error messages (e.g., DioError gets converted to "user not found"). | In OwnerService, catch all exceptions and return a single generic `AuthFailure('Authentication failed.')` — consistent with existing masking on other endpoints. Review `owner_auth_controller` errorMessage presentation; existing tests ensure it only shows the generic failure string. |
| Forgot password route not properly rate-limited and gets brute-forced. | Express `rate-limit` middleware is already globally applied (security stack in app.js). Additional per-route limiter not needed for a single-owner app. |
| Owner changes password via Firebase link but it doesn't match local password hash in sqflite. | On next login, `OwnerService.loginOwner` calls `_signInOrCreateWithRetries` with Firebase first — only if Firebase auth succeeds does it proceed. The local sqflite `passwordHash` is for offline comparison; the cloud (Firebase) is the source of truth. On successful Firebase login, the `OwnerRepository.saveProfile(profile)` call updates local state, so the stale local hash doesn't block subsequent cloud logins. |
