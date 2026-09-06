# JonkStore POS Backend

Production-ready **Node.js + Express** backend foundation for the JonkStore mobile
point-of-sale application. The Flutter mobile app (under `../lib/`) will consume
this backend via its `lib/api` layer.

This repository contains **only the foundation** — no business features, no AI,
no mock data, no fake authentication.  It wires up security, observability,
configuration, storage primitives, and the route scaffolding so that future
modules (auth, products, inventory, sales, reports, etc.) can be implemented on
top of a hardened base.

---

## Backend Purpose

- Expose a versioned JSON API (`/api/...`) for JonkStore POS clients (mobile,
  future web admin).
- Verify Firebase Auth ID tokens issued by the mobile app and attach
  `req.user` with role/permission metadata from custom claims.
- Send transactional email (including owner OTPs in the future) via SMTP.
- Accept and safely store uploaded files (product images, customer photos,
  business logos, PDF receipts) on local disk; the API can later authorize
  downloads or forward object storage.
- Report real service health and dependency status via `GET /api/health`.
- Provide a consistent error shape, request IDs, structured logs, rate limits,
  and CSP/Helmet hardening out of the box.

---

## Directory Structure

```
backend/
├── src/
│   ├── app.js                    # Express assembly: middleware, routes, errors
│   ├── server.js                 # Entry point: boot, listen, graceful shutdown
│   ├── config/                   # Environment-loaded configuration modules
│   │   ├── environment.js        # NODE_ENV, CORS, rate limits, logging, etc.
│   │   ├── firebase.js           # Firebase Admin credential extraction
│   │   ├── smtp.js               # Nodemailer transport config
│   │   ├── server.js             # HTTP server tuning (body size, timeouts)
│   │   ├── storage.js            # Upload directories + MIME allow-lists
│   │   └── database.js           # PostgreSQL credentials (future)
│   ├── controllers/
│   │   ├── health.controller.js  # Real server health information
│   │   └── common.controller.js  # 501 "not implemented" route factory
│   ├── middleware/
│   │   ├── auth.middleware.js    # Firebase token verification + role/perm gates
│   │   ├── cors.middleware.js    # CORS with per-origin allow-list
│   │   ├── error.middleware.js   # Central error handler + 404
│   │   ├── logging.middleware.js # Request ID + Morgan -> Pino bridge
│   │   ├── rateLimit.middleware.js # Global + strict rate limiters
│   │   ├── security.middleware.js # Helmet CSP/HSTS/frameguard
│   │   └── validation.middleware.js # Zod body/query/params validator
│   ├── routes/
│   │   ├── index.js              # API route aggregator
│   │   ├── health.routes.js      # GET /api/health
│   │   ├── auth.routes.js        # /api/auth/* (stubs → 501)
│   │   ├── businesses.routes.js  # /api/businesses/* (stubs → 501)
│   │   ├── products.routes.js    # /api/products/* (stubs → 501)
│   │   ├── inventory.routes.js   # /api/inventory/* (stubs → 501)
│   │   ├── purchases.routes.js   # /api/purchases/* (stubs → 501)
│   │   ├── customers.routes.js   # /api/customers/* (stubs → 501)
│   │   ├── sales.routes.js       # /api/sales/* (stubs → 501)
│   │   ├── payments.routes.js    # /api/payments/* (stubs → 501)
│   │   ├── reports.routes.js     # /api/reports/* (stubs → 501)
│   │   └── notifications.routes.js # /api/notifications/* (stubs → 501)
│   ├── services/
│   │   ├── firebase.service.js   # Firebase Admin: token verify + user mgmt
│   │   ├── email.service.js      # Nodemailer: sendEmail() + owner OTP
│   │   └── storage.service.js    # Multer wrappers per upload category
│   ├── repositories/             # (future: data access layer, .gitkeep only)
│   ├── models/                   # (future: DTOs / domain models, .gitkeep)
│   ├── validators/
│   │   └── common.validators.js  # Shared Zod schemas (login, pagination…)
│   └── utils/
│       ├── errors.js             # AppError / NotFound / Validation / Auth…
│       ├── logger.js             # Pino logger with secret redaction
│       ├── file.js               # Safe filenames + directory helpers
│       └── helpers.js            # asyncHandler, request ID, crypto utils
├── uploads/                      # Local upload root (NOT in git)
│   ├── products/
│   ├── customers/
│   ├── businesses/
│   └── receipts/
├── tests/
│   ├── jest.setup.js             # Jest bootstrap + NODE_ENV=test
│   ├── test-helpers.js           # Mock services + test-server builder
│   ├── server.test.js            # Boot, request-ID, / route
│   ├── health.test.js            # /api/health payload shape
│   ├── validation.test.js        # Zod middleware + shared validators
│   ├── errors.test.js            # Error classes + central handler
│   └── auth.test.js              # Auth/role/permission middleware
├── .env.example                  # Environment variable template
├── .gitignore
├── package.json
└── README.md
```

---

## Environment Variables

Copy `.env.example` → `.env` and fill in real values. **Never commit `.env`.**

| Variable | Purpose |
|---|---|
| `NODE_ENV` | `development` / `test` / `production` |
| `PORT` / `HOST` | HTTP server bind (default `3000` / `0.0.0.0`) |
| `API_PREFIX` | URL prefix for all routes (default `/api`) |
| `CORS_ORIGIN` | Comma-separated allowed origins |
| `RATE_LIMIT_WINDOW_MS` / `RATE_LIMIT_MAX_REQUESTS` | Global rate limit |
| `REQUEST_BODY_LIMIT` | Max request body size (default `10mb`) |
| `FIREBASE_PROJECT_ID` | Firebase project identifier |
| `FIREBASE_CLIENT_EMAIL` | Service account client email |
| `FIREBASE_PRIVATE_KEY_BASE64` | Service account private key **base64 encoded** |
| `FIREBASE_STORAGE_BUCKET` | Optional GCS bucket (e.g. `proj.appspot.com`) |
| `SMTP_HOST` / `SMTP_PORT` | SMTP server host and port |
| `SMTP_SECURE` | `true` for port 465, `false` for STARTTLS on 587 |
| `SMTP_USER` / `SMTP_PASS` | SMTP credentials |
| `SMTP_FROM_NAME` / `SMTP_FROM_EMAIL` | Default `From:` header |
| `STORAGE_UPLOAD_DIR` | Upload root (default `./uploads`) |
| `STORAGE_MAX_FILE_SIZE_BYTES` | Max single file (default `10485760` = 10 MB) |
| `STORAGE_ALLOWED_IMAGE_MIMES` | Comma list of allowed image MIME types |
| `STORAGE_ALLOWED_DOC_MIMES` | Comma list of allowed document MIME types |
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_NAME` / `DATABASE_USER` / `DATABASE_PASSWORD` / `DATABASE_SSL` | PostgreSQL (future integration) |
| `LOG_LEVEL` | Pino level: `trace`/`debug`/`info`/`warn`/`error`/`fatal` |
| `LOG_PRETTY` | Pretty-print logs in dev |
| `JWT_SECRET` | Reserved for future custom JWT flows |
| `BCRYPT_ROUNDS` | Reserved for future local password hashing |

Two Firebase credential modes are supported:
1. **Per-field (recommended):** set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`,
   `FIREBASE_PRIVATE_KEY_BASE64` (base64 of the raw PEM key only, without quotes
   or literal `\n`).
2. **Whole-service-account blob:** set `FIREBASE_SERVICE_ACCOUNT_BASE64` to the
   base64 of the entire `service-account.json`.

---

## Installation

```bash
cd backend
npm install
cp .env.example .env
# edit .env with real values (at minimum set FIREBASE_* and SMTP_* for prod)
```

Requires **Node.js ≥ 18**.

---

## Development Server

```bash
cd backend
npm run dev
```

`nodemon` will reload on changes to `src/**/*.js`.

Default URLs after boot:
- Root info: http://localhost:3000/
- Health check: http://localhost:3000/api/health

---

## Running Tests

```bash
cd backend
npm test                 # all suites
npm run test:watch       # interactive watch
npm run test:coverage    # Jest coverage report
```

Tests use supertest + a real in-process HTTP server on a random port. Firebase
and SMTP services are substituted with lightweight mock implementations in
`tests/test-helpers.js` so the suite runs offline and without credentials.

---

## Production Server

```bash
cd backend
npm ci
NODE_ENV=production PORT=3000 npm start
```

In production deploy behind a reverse proxy (nginx / Cloudflare / ALB):
- Terminate TLS at the edge.
- Set `trust proxy: 1` via the config so request IPs are correct.
- Run under a process manager (systemd, pm2, k8s Deployment) that restarts on
  exit 0/1 and routes `SIGTERM` to the process for graceful shutdown.

Health endpoint: `GET /api/health` returns 200 with dependency status. Use it
for liveness/readiness probes.

---

## Security Principles

1. **Secrets never in source.** All credentials loaded from `.env` and validated
   at startup. Pino redacts 20+ common secret fields (authz headers, OTPs,
   passwords) from logs.
2. **Helmet + CSP + frameguard.** Default Content-Security-Policy is restrictive;
   relax per endpoint via controller-level overrides if you later serve HTML.
3. **Signed tokens only.** Auth middleware verifies Firebase ID tokens server-side
   with the Admin SDK (`verifyIdToken`). No unsigned JWTs.
4. **Role + permission gates.** `requireRole('owner','admin')` and
   `requirePermission('manageSuppliers')` can be composed on any route.
5. **Global rate limit** plus a reusable `buildStrictRateLimiter()` helper for
   OTP / password-reset endpoints.
6. **File uploads isolated by category** (products/customers/businesses/receipts)
   with per-upload MIME allow-list, size cap, UUID + timestamp + random token
   file names, and path-traversal guard when resolving stored paths.
7. **No stack traces to clients** in production. Central error middleware
   converts unknown errors to `INTERNAL_ERROR` and logs the original.
8. **Graceful shutdown.** `SIGTERM`/`SIGINT` close the HTTP server, drain the
   Nodemailer pool, and exit 0 within a configurable grace period.
9. **Compression** via `compression` and **body size caps** via both Express
   `limit` and Multer `limits.fileSize`.

---

## Future Firebase Integration

This backend already initializes `firebase-admin` and exposes:

- `firebaseAdminService.verifyIdToken(token, checkRevoked)` — used by auth middleware.
- `firebaseAdminService.getUserByUid(uid)` / `createUser()` / `setCustomUserClaims()`.
- `firebaseAdminService.generateEmailVerificationLink()` / `generatePasswordResetLink()`.
- `firebaseAdminService.firestore()` / `storage()` accessors for future sync jobs.

Integration steps when ready:
1. Populate `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
   `FIREBASE_PRIVATE_KEY_BASE64` from a least-privilege service account.
2. Mirror custom claims (`role`, `permissions[]`) into `setCustomUserClaims()`
   whenever roles change — auth middleware reads them from verified tokens.
3. Implement `routes/auth.routes.js` stubs against the services, following the
   same validation + error conventions used in tests.

---

## Future PostgreSQL Integration

Configuration stubs live in `src/config/database.js` and `src/repositories/` +
`src/models/` directories are reserved for:

- `pg` / `pg-promise` driver with connection pooling.
- Repository classes per aggregate root (Business, Product, Sale, Customer…).
- Transaction scripts for purchase orders and stock transfers.

Integration steps when ready:
1. Add `pg` (and optionally `knex` / `drizzle`) to `package.json`.
2. Populate `DATABASE_*` env vars with credentials for a dedicated app user.
3. Add `/health` check that performs a `SELECT 1` probe and flips
   `services.database.status` between `operational` / `degraded`.

---

## Future AI Integration

(AI is deliberately **not** wired today.) Reserved touch-points:
- `src/services/` → add `ai.service.js` wrapping embeddings + chat providers.
- `routes/reports.routes.js` already exposes `/reports/*` where AI summaries
  can live.
- `validators/common.validators.js` pattern should be followed for any new
  text-generation payloads (input length limits, PII filters).
- PostgreSQL column types for vector search were planned in the mobile schema
  (`lib/database/schema/014_ai.sql`) and can be mirrored here once PG is wired.
