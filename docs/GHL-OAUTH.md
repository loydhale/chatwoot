# GHL OAuth Integration — Technical Reference

> DeskFlow ↔ GoHighLevel OAuth 2.0 Authorization Code flow.
> Last updated: 2026-02-01 by Avery 🛡️ (CTO)

---

## Architecture Overview

DeskFlow integrates with GHL as a **Marketplace App**. Tokens are stored in the
existing `integrations_hooks` table (Chatwoot's hook system) with `app_id = 'gohighlevel'`.

We intentionally avoided a separate `ghl_connections` table — the hook model already
provides `access_token`, `settings` (JSONB for refresh tokens / metadata), `reference_id`
(GHL location ID), and `account_id` scoping. One less table to maintain.

---

## OAuth Flow (Step by Step)

```
┌──────────┐   1. Click "Connect GHL"   ┌──────────┐
│ DeskFlow │ ──────────────────────────▶ │  Rails   │
│ Frontend │                             │  API     │
└──────────┘                             └────┬─────┘
                                              │
     2. POST /api/v1/accounts/:id/ghl/authorization
        → Generates JWT state token (HS256, 15min TTL)
        → Returns { url: "https://marketplace.gohighlevel.com/oauth/chooselocation?..." }
                                              │
┌──────────┐   3. Redirect to GHL           │
│   GHL    │ ◀──────────────────────────────┘
│ OAuth    │
│ Server   │   4. User authorizes, GHL redirects back
│          │ ──────────────────────────────▶ ┌──────────┐
└──────────┘   GET /ghl/callback             │  Rails   │
               ?code=AUTH_CODE               │ Callback │
               &state=JWT_TOKEN              └────┬─────┘
                                                  │
     5. Verify JWT state → extract account_id
     6. Exchange code for tokens:
        POST https://services.leadconnectorhq.com/oauth/token
        → access_token, refresh_token, expires_in, locationId, etc.
                                                  │
     7. Upsert integrations_hooks record:
        app_id:       'gohighlevel'
        access_token: (encrypted)
        reference_id: locationId
        settings:     { refresh_token, expires_at, scope, ... }
                                                  │
     8. Redirect to /app/accounts/:id/settings/integrations/gohighlevel
```

---

## Endpoints

### Initiate OAuth
```
POST /api/v1/accounts/:account_id/ghl/authorization
```
- **Auth:** Admin-only (Pundit)
- **Response:** `{ success: true, url: "..." }`
- **Controller:** `Api::V1::Accounts::Ghl::AuthorizationController#create`

### OAuth Callback
```
GET /ghl/callback?code=xxx&state=jwt
```
- **Auth:** None (public — JWT state validates account)
- **Controller:** `Ghl::CallbacksController#show`
- **On success:** Redirects to integration settings page
- **On failure:** Redirects with `?error=reason`

### Check Connection Status
```
GET /api/v1/accounts/:account_id/integrations/ghl/status
```
- **Auth:** Admin-only
- **Response:** `{ connected: true, location_id: "...", expires_at: "..." }`
- **Controller:** `Api::V1::Accounts::Integrations::GhlController#status`

### Refresh Tokens
```
POST /api/v1/accounts/:account_id/integrations/ghl/refresh
```
- **Auth:** Admin-only
- **Also runs automatically:** `Integrations::Ghl::RefreshTokensJob` every 12h
- **Controller:** `Api::V1::Accounts::Integrations::GhlController#refresh`

### Disconnect
```
DELETE /api/v1/accounts/:account_id/integrations/ghl
```
- **Auth:** Admin-only
- **Controller:** `Api::V1::Accounts::Integrations::GhlController#destroy`

### Webhook Receiver
```
POST /webhooks/ghl
```
- **Auth:** HMAC-SHA256 signature (`X-GHL-Signature` header)
- **Controller:** `Webhooks::GhlController#process_payload`
- **Handled events:** `ContactCreate`, `ContactUpdate`, `ContactDelete`, `InboundMessage`, `OutboundMessage`

---

## File Map

```
app/
├── controllers/
│   ├── ghl/
│   │   └── callbacks_controller.rb          # OAuth callback (GET /ghl/callback)
│   ├── api/v1/accounts/
│   │   ├── ghl/
│   │   │   └── authorization_controller.rb  # Initiate OAuth (POST .../ghl/authorization)
│   │   └── integrations/
│   │       └── ghl_controller.rb            # Status / refresh / disconnect
│   ├── webhooks/
│   │   └── ghl_controller.rb                # Webhook receiver
│   └── concerns/
│       └── ghl_concern.rb                   # OAuth2 client factory, scopes
├── helpers/
│   └── ghl/
│       └── integration_helper.rb            # JWT state token generation/verification
├── services/
│   └── ghl/
│       ├── token_refresh_service.rb         # OAuth2 token refresh
│       └── contact_sync_service.rb          # Bidirectional contact sync
├── jobs/
│   ├── integrations/ghl/
│   │   └── refresh_tokens_job.rb            # Scheduled token refresh (every 12h)
│   └── webhooks/
│       └── ghl_events_job.rb                # Async webhook event processing
└── models/
    └── integrations/
        └── hook.rb                          # Token storage (app_id: 'gohighlevel')

config/
├── routes.rb                                # All GHL routes defined here
├── integration/apps.yml                     # 'gohighlevel' app definition
├── schedule.yml                             # sidekiq-cron: ghl_refresh_tokens_job
└── locales/en.yml                           # i18n strings

db/migrate/
└── 20260201231000_add_ghl_indexes_to_integrations_hooks.rb  # Performance indexes
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GHL_CLIENT_ID` | Yes | OAuth client ID from GHL Marketplace app |
| `GHL_CLIENT_SECRET` | Yes | OAuth client secret (also used for JWT signing) |
| `GHL_WEBHOOK_SECRET` | Recommended | Webhook signature verification (falls back to `GHL_CLIENT_SECRET`) |
| `FRONTEND_URL` | Yes | Base URL for OAuth redirect (e.g., `https://app.deskflow.ai`) |

These are loaded via `GlobalConfigService` which checks `InstallationConfig` first,
then falls back to `ENV`. Set them in `.env` or via the Super Admin panel.

---

## Token Storage

Tokens live in `integrations_hooks`:

| Column | Usage |
|--------|-------|
| `access_token` | GHL access token (encrypted at rest via ActiveRecord encryption) |
| `reference_id` | GHL location ID (used for webhook → account routing) |
| `settings` | JSONB: `refresh_token`, `expires_at`, `scope`, `location_id`, `company_id`, `user_id`, `connected_at` |
| `status` | `enabled` / `disabled` |
| `app_id` | Always `'gohighlevel'` |

### Token Lifecycle
- **Access tokens** expire in ~24h (GHL standard)
- **Refresh tokens** are long-lived but single-use (new one issued each refresh)
- `RefreshTokensJob` runs every 12h and refreshes tokens expiring within 6h
- Failed refreshes are logged but don't disable the hook (retry on next run)

---

## Scopes Requested

| Scope | Purpose |
|-------|---------|
| `contacts.readonly` | Read contact data for sidebar context |
| `contacts.write` | Create/update contacts from DeskFlow |
| `conversations.readonly` | Import conversation history |
| `conversations.write` | Send support replies |
| `conversations/message.readonly` | Read message content |
| `conversations/message.write` | Send messages via GHL |
| `locations.readonly` | Get sub-account info |
| `users.readonly` | Map GHL users to DeskFlow agents (SSO) |

---

## Webhook Events

Subscribed in the GHL Marketplace app settings:

| GHL Event | DeskFlow Action |
|-----------|-----------------|
| `ContactCreate` | Create contact via `ContactSyncService` |
| `ContactUpdate` | Update contact attributes |
| `ContactDelete` | Soft-archive (set `ghl_deleted` custom attribute) |
| `InboundMessage` | Queue for `MessageSyncService` (future) |
| `OutboundMessage` | Queue for `MessageSyncService` (future) |

Webhook signature verification uses HMAC-SHA256 with `GHL_WEBHOOK_SECRET`.

---

## Security Considerations

1. **JWT State Parameter** — 15-minute TTL, HS256-signed with `GHL_CLIENT_SECRET`. Prevents CSRF on callback.
2. **Token Encryption** — `access_token` encrypted at rest via `ActiveRecord::Encryption` (when encryption keys are configured).
3. **Webhook Verification** — HMAC-SHA256 signature check on every webhook. Rejects unsigned requests.
4. **Admin-Only** — OAuth initiation and management endpoints require administrator role.
5. **No Raw Secrets in Logs** — Token values are never logged. Only hook IDs and account IDs appear in logs.

---

## What's Missing / Next Steps

### Phase 2: Message Sync (DSK-012)
- [ ] `Ghl::MessageSyncService` — referenced in `GhlEventsJob` but not yet implemented
- [ ] `Channel::Ghl` model — for native channel support in conversations
- [ ] Delivery status tracking (sent/delivered/read)

### Phase 3: SSO (DSK-013)
- [ ] GHL SSO login flow (user clicks DeskFlow from GHL sidebar)
- [ ] `ghl_user_id` column on `users` table
- [ ] Auto-provisioning of DeskFlow agents from GHL users

### Phase 4: Enhanced Sync
- [ ] `ghl_contact_id` indexed column on `contacts` (currently uses `identifier` + `custom_attributes`)
- [ ] Bulk import UI in settings
- [ ] Sync status dashboard

---

## Troubleshooting

### "GHL OAuth credentials not configured"
Set `GHL_CLIENT_ID` and `GHL_CLIENT_SECRET` in `.env` or via Super Admin > Installation Config.

### Callback returns `?error=token_exchange_failed`
- Check that `GHL_CLIENT_SECRET` matches the GHL Marketplace app
- Check that `FRONTEND_URL` matches the redirect URI registered in GHL
- Check Rails logs for the OAuth2 error response body

### Tokens expiring / API calls failing with 401
- Verify `RefreshTokensJob` is running (check Sidekiq dashboard)
- Manually trigger refresh: `POST /api/v1/accounts/:id/integrations/ghl/refresh`
- Check `settings['expires_at']` on the hook

### Webhook events not arriving
- Verify webhook URL in GHL Marketplace: `https://app.deskflow.ai/webhooks/ghl`
- Check `X-GHL-Signature` header is present
- Verify `GHL_WEBHOOK_SECRET` matches GHL app config

---

*For marketplace submission checklist, see `docs/GHL_MARKETPLACE_CHECKLIST.md`.*
*For the original requirements spec, see `docs/GHL_OAUTH_INTEGRATION.md`.*
