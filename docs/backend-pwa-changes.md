# Backend Changes for PWA Rollout

This document lists backend-side changes/verification needed for the current PWA-enabled client.

## 1. Auth + Token Verification (Required)

The app now signs in on web via Firebase popup (`FirebaseAuth.signInWithPopup`) and sends Firebase ID tokens to backend APIs.

Backend must:
- Continue accepting `Authorization: Bearer <firebase_id_token>`.
- Verify Firebase ID tokens server-side for protected routes.
- Treat `/health` (and `/`) as unauthenticated if desired.

Client behavior:
- All API routes except `/` and `/health` send bearer token.
- Token refresh/retry is handled on client; backend should return proper `401/403`.

## 2. CORS for PWA Origin (Required if API is cross-origin)

If API is hosted on a different origin than the PWA host, backend CORS must allow:
- Origin: deployed PWA origin(s), e.g. `https://<your-domain>`.
- Methods: `GET, POST, DELETE, OPTIONS`.
- Headers: `Authorization, Content-Type`.
- Credentials: only if you explicitly need cookies (not required for current bearer-token flow).

## 3. Payments API Contract (Required)

### `POST /payments/initiate`
Client expects status `ok` and currently requires:
- `order_id`
- `token`
- `merchant_id`
- `merchant_order_id`

For web flow, backend must additionally return:
- `payment_url` (absolute HTTPS URL; used to open external payment page)

Optional (already parsed by client):
- `payment_mode`

### `POST /payments/verify/{hold_id}`
Request body:
- `merchant_order_id`

Response on success must include:
- `status: "ok"`
- `order_id`

## 4. Error Semantics (Recommended)

Keep these stable so UI behavior remains correct:
- `401`: token invalid/expired -> client triggers re-auth behavior.
- `403`: forbidden.
- `409`: business conflict flows (already handled in multiple screens).
- JSON error body with `error` (or `message`) string.

## 5. Domain Restriction Policy (Optional but Recommended)

Client enforces allowed domains via `ALLOWED_GOOGLE_DOMAINS`, but backend should also enforce if this is a hard policy:
- Validate email/domain from verified Firebase token claims or linked user profile.
- Do not rely only on client-side filtering.

## 6. No New Backend Requirement for App-Only UX Features

These are client-only and require no backend changes:
- QR-screen fullscreen button (web)
- Brightness handling on mobile
- Standalone-PWA entry gating
- Install page and manifest handling

## 7. Deployment Checklist (Backend-facing)

- Ensure API TLS is valid (`https`) for production PWA.
- Ensure CORS is configured for the final PWA domain.
- Confirm payment gateway return/callback domain whitelist includes production app domain if gateway requires it.
- Smoke test:
  1. Sign in
  2. Create hold
  3. Initiate payment (web + mobile)
  4. Verify payment
  5. Fetch orders

