# DeskFlow Full Code Audit Report
**Date:** 2026-02-03 | **Ordered by:** Loyd | **Method:** 5 parallel Codex agents on isolated worktrees

## Executive Summary
5 audit chunks completed across rebrand, Docker/CI, GHL integration, frontend, and backend/DB. **1 critical**, **3 high**, **5 medium**, **1 low** severity findings. All agents ran in read-only sandbox — fixes need manual application.

---

## Chunk 1: Rebrand Integrity
**Agent:** quick-reef → nimble-prairie (covered by frontend audit)

### Findings
- **13 files** with `deskflowss.ai` typo (double 's') — spec/fixture files
- 1 stale Chatwoot branding string in `en/conversation.json:257` ("Reply from Chatwoot…")
- No hardcoded Chatwoot API URLs found
- Chatwoot references limited to package imports (`@chatwoot/utils`, `@chatwoot/prosemirror-schema`)
- **Domain question:** `deskflows.ai` vs `deskflows.app` needs alignment

### Files to Fix
```
app/javascript/widget/helpers/specs/campaignHelper.spec.js:24,31
app/javascript/portal/specs/portal.spec.js:62,71,79,144
app/javascript/dashboard/helper/specs/portalHelper.spec.js:7,20,31,47,63,68
app/javascript/dashboard/store/modules/specs/labels/fixtures.js:12
app/javascript/dashboard/i18n/locale/en/conversation.json:257
```

---

## Chunk 2: Docker & CI
**Agent:** sharp-mist | **Status:** ✅ Complete

### Findings
- **BUILD BLOCKER:** `asset-builder` stage in `docker/Dockerfile` missing `BUNDLE_WITHOUT="development:test"` — causes asset precompile to fail trying to load dev/test gems
- **Optional:** Redis healthcheck in `docker-compose.yaml` hardcodes password `"redis"` — should use `$REDIS_PASSWORD`
- No stale `chatwoot/*` image names in Dockerfiles, compose, or workflows
- Workflows correctly reference `deskflows/*` images
- `.dockerignore` is comprehensive

### Patch
```diff
# docker/Dockerfile — asset-builder stage
+ARG BUNDLE_WITHOUT="development:test"
+ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
# After gem install bundler:
+&& bundle config set without 'development test'

# docker-compose.yaml — Redis healthcheck
-test: ["CMD", "redis-cli", "-a", "redis", "ping"]
+test: ["CMD-SHELL", "redis-cli -a \"$REDIS_PASSWORD\" ping"]
```

---

## Chunk 3: GHL Integration
**Agent:** kind-shore | **Status:** ✅ Complete

### Findings (by severity)

**🔴 Critical:**
- Hardcoded PIT token and location ID defaults — any account hits PIT fallback if env vars unset
  - `app/controllers/api/v1/accounts/integrations/ghl_controller.rb:62,85,140,155`

**🟠 High:**
- OAuth callback exchanges codes before validating `state` — CSRF risk
  - `app/controllers/ghl/callbacks_controller.rb:18,26`
- Refresh tokens stored in JSON settings (unencrypted) — access token IS encrypted, refresh is NOT
  - `app/controllers/ghl/callbacks_controller.rb:139`
  - `app/services/ghl/workspace_provisioning_service.rb:154`
- Race conditions on create-then-find paths — `RecordNotUnique` risk, `message_already_synced?` non-atomic
  - `app/services/ghl/contact_sync_service.rb:15`
  - `app/services/ghl/message_sync_service.rb:22,135`

**🟡 Medium:**
- Opportunity create swallows `RecordInvalid`, preventing Sidekiq retries
  - `app/services/ghl/opportunity_sync_service.rb:26`
- Non-atomic location count/usage update, assumes `usage_data` non-nil
  - `app/jobs/webhooks/ghl_events_job.rb:117`
- Message sync falls back to "most recent open conversation" — mis-threading risk
  - `app/services/ghl/message_sync_service.rb:164`
- Bulk contact import is N+1 (per-record lookup + update)
  - `app/services/ghl/contact_sync_service.rb:90,198`

**🟢 Low:**
- Stale docs: MessageSyncService marked "not implemented" in `docs/GHL-OAUTH.md`

### Spec Coverage
- 140 specs all assert real behavior (no no-ops)
- **Gaps:** PIT fallback security, state-before-token-exchange, `send_message`, `import_all_contacts`, race condition handling

---

## Chunk 4: Frontend
**Agent:** nimble-prairie | **Status:** ✅ Complete
(Merged with Chunk 1 rebrand findings above)

---

## Chunk 5: Backend & DB
**Agent:** vivid-slug | **Status:** ✅ Complete

### Findings

**Data Integrity:**
- Schema declares only **4 foreign keys** — most `account_id`/`inbox_id`/`*_id` relationships unenforced
  - `db/schema.rb:1305`

**Missing FK Indexes (20+):**
- Join tables: `agent_bot_inboxes`, `folders`, `integrations_hooks`, `webhooks`
- Content: `article_embeddings` (article_id), `articles` (category_id/folder_id)
- Campaigns/macros: `campaigns` (sender_id), `macros` (created_by_id/updated_by_id)
- Accounts: `account_users` (inviter_id)
- **10 channel tables** missing `account_id` indexes: api, email, instagram, line, sms, telegram, tiktok, twilio_sms, web_widgets, whatsapp

**Job Error Handling:**
- Jobs swallow exceptions, blocking Sidekiq retries:
  - `WebhookJob` → `lib/webhooks/trigger.rb`
  - `HookJob` → `app/jobs/hook_job.rb`
  - `AutoAssignment::AssignmentJob`
  - `Inboxes::FetchImapEmailsJob`

**Security:**
- `config/database.yml:20` — static default prod credentials if env vars missing
- `config/environments/production.rb:33` — `force_ssl` defaults to false

**Gems:**
- Git-sourced chatwoot forks increase maintenance surface
- Rubocop couldn't run (Bundler 2.5.16 not installed)

---

## Priority Fix Order
1. **Critical:** Remove PIT token hardcoding (GHL controller)
2. **High:** Docker BUNDLE_WITHOUT fix (unblocks CI)
3. **High:** OAuth state validation before code exchange
4. **High:** Encrypt refresh tokens
5. **High:** Race condition fixes (find_or_create_by + unique indexes)
6. **Medium:** Fix `deskflowss` typos (13 files)
7. **Medium:** Add missing DB indexes (migration)
8. **Medium:** Fix job error swallowing
9. **Low:** Update stale docs

## Notes
- All agents ran in Codex read-only sandbox — none could apply fixes
- Rubocop unavailable (Bundler version mismatch)
- Domain alignment needed: `deskflows.ai` vs `deskflows.app`
