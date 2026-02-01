# DeskFlow — What's Left To Ship

> Current status and remaining work to get DeskFlow on the GHL Marketplace.

---

## ✅ Completed

### Rebranding (100%)
- [x] Chatwoot → DeskFlow across ~1,200 files
- [x] Captain AI → Atlas AI
- [x] Locale files (703+ files, all languages)
- [x] Vue/JS components (144+ files)
- [x] Ruby files (187+ files)
- [x] Spec/test files (116+ files)
- [x] Placeholder logos (SVG)
- [x] README, BRANDING, documentation

### GHL OAuth Backend (90%)
- [x] `GhlConcern` module — OAuth2 client config
- [x] `Ghl::IntegrationHelper` — JWT state token generation/verification
- [x] `Ghl::CallbacksController` — OAuth callback handler
- [x] `Api::V1::Accounts::Ghl::AuthorizationController` — initiate OAuth flow
- [x] `Api::V1::Accounts::Integrations::GhlController` — status, refresh, destroy
- [x] `Integrations::App` model — GHL integration registered
- [x] Routes configured (`/ghl/callback`, `/api/v1/accounts/:id/ghl/*`)
- [x] i18n strings for GHL integration
- [x] Integration app config YAML (`config/integration/apps.yml`)
- [x] GHL logo in `public/dashboard/images/integrations/gohighlevel.png`
- [x] `.env.example` updated with GHL variables

### Docker Setup (80%)
- [x] docker-compose.yaml with all services
- [x] Dockerfile for multi-stage build
- [x] Rails + Vite + Sidekiq service Dockerfiles
- [x] Entrypoint scripts
- [x] Docker env overrides for Postgres/Redis service names
- [x] `.env.docker` reference file

---

## 🔨 In Progress

### Local Dev Environment
- [x] Docker build initiated (base image compiles ~5-10 min)
- [ ] Verify full `docker compose up` boots
- [ ] Run `db:chatwoot_prepare` to create/migrate database
- [ ] Confirm Rails server responds on port 3000
- [ ] Confirm Vite dev server on port 3036

---

## ⏳ Remaining Work

### Phase 1: Dev Environment (Days)
| Task | Effort | Priority |
|------|--------|----------|
| Verify Docker Compose full boot | 1h | **P0** |
| Test create account flow | 1h | **P0** |
| Document any boot errors and fixes | 1h | **P0** |

### Phase 2: GHL Integration Completion (1-2 Weeks)
| Task | Effort | Priority |
|------|--------|----------|
| Create `ghl_connections` migration | 2h | **P1** |
| Test OAuth flow with GHL dev app | 4h | **P1** |
| Token refresh background job | 4h | **P1** |
| Webhook receiver (`POST /api/v1/webhooks/ghl`) | 8h | **P1** |
| Webhook signature verification | 2h | **P1** |
| Contact sync service | 8h | **P1** |
| Message sending via GHL API | 8h | **P1** |
| Vue.js frontend for GHL settings page | 4h | **P2** |
| SSO login from GHL dashboard | 8h | **P2** |

### Phase 3: Marketplace Readiness (1-2 Weeks)
| Task | Effort | Priority |
|------|--------|----------|
| Production deployment (Render/Railway) | 4h | **P1** |
| SSL + custom domain (deskflow.ai) | 2h | **P1** |
| Privacy policy page | 4h | **P1** |
| Terms of service page | 4h | **P1** |
| App screenshots (3-5) | 4h | **P1** |
| Proper logo design (512x512 PNG) | 4h | **P1** |
| Demo video (2-3 min) | 8h | **P2** |
| GHL Marketplace submission | 2h | **P1** |

### Phase 4: White-Label Features (2-3 Weeks)
| Task | Effort | Priority |
|------|--------|----------|
| Per-account branding (logo/colors) | 16h | **P2** |
| Custom domain routing | 8h | **P2** |
| AI usage metering for billing | 16h | **P2** |

---

## 🚧 Known Issues

1. **No GHL-specific Vue component** — The backend integration is built, but there's no custom Vue page for GHL settings. The generic integration hook UI may work, but a dedicated page would be better.

2. **No `ghl_connections` migration** — The OAuth integration stores tokens in the `hooks` table (existing Chatwoot pattern), not the proposed `ghl_connections` table from the docs. This works fine but differs from the architecture doc.

3. **No webhook receiver** — The `/api/v1/webhooks/ghl` endpoint documented in `GHL_OAUTH_INTEGRATION.md` does not exist yet. This is needed to receive events from GHL.

4. **Docker compose env overlap** — `.env` has `POSTGRES_HOST=localhost` which is correct for non-Docker local dev but wrong for Docker. Fixed by adding `environment:` overrides in docker-compose.yaml.

5. **`version: '3'` warning** — Docker Compose v2 warns about the obsolete `version` key. Removed.

6. **Ruby version** — System Ruby is 2.6.10, app requires 3.4.4. Docker handles this, but non-Docker dev requires rbenv/asdf.

---

## 🔑 GHL OAuth Code Review Notes

### What's Good
- Clean OAuth2 implementation using the `oauth2` gem
- JWT-based state parameter for CSRF protection
- Token storage in the existing `hooks` table (consistent with Slack/Linear pattern)
- Proper error handling and logging
- Token refresh endpoint exists
- Integration properly registered in `config/integration/apps.yml`
- i18n strings added

### What Needs Work
- **Token refresh job** — There's a refresh endpoint but no Sidekiq job to proactively refresh tokens before expiry (GHL tokens last 24h)
- **Webhook receiver** — Not implemented yet
- **Webhook signature verification** — Not implemented
- **Contact sync** — Not implemented
- **Message sending** — Not implemented
- **Vue.js frontend** — No dedicated GHL integration page (uses generic integration UI)

### Architecture Decision
The code stores GHL tokens in the `hooks` table, not a separate `ghl_connections` table. This is actually the smarter approach — it follows the existing Chatwoot pattern for integrations (same as Slack, Linear, etc.) and doesn't require a new migration. The docs should be updated to reflect this.

---

## 📊 Effort Estimate to GHL Marketplace

| Phase | Estimate |
|-------|----------|
| Dev environment working | 1 day |
| GHL OAuth tested end-to-end | 3 days |
| Webhook + Contact sync | 5 days |
| Production deployment | 2 days |
| Legal docs + branding | 3 days |
| Marketplace submission | 1 day |
| **Total** | **~3 weeks** |

---

*Last updated: 2026-01-30*
