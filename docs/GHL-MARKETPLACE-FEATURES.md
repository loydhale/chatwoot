# GHL Marketplace Features

> DeskFlows.ai — White-label customer support platform for GoHighLevel marketplace

## Overview

DeskFlows integrates with GoHighLevel as a marketplace app. When a GHL agency or location installs DeskFlows, the following happens automatically:

1. **OAuth flow** → User authorizes DeskFlows
2. **Workspace provisioning** → Account, admin user, inbox, and subscription are created
3. **Contact sync** → Bidirectional contact sync begins via webhooks
4. **Message sync** → Conversations from GHL flow into DeskFlows
5. **AI assistant (Hudley)** → AI credits are metered per plan

## Architecture

```
GHL Marketplace
    │
    ├── OAuth Install → Ghl::CallbacksController
    │                     └── Ghl::WorkspaceProvisioningService
    │                           ├── Create Account
    │                           ├── Create Admin User
    │                           ├── Create GhlSubscription (trial)
    │                           ├── Create Integration Hook
    │                           └── Create Default Inbox
    │
    ├── Webhooks → Webhooks::GhlController
    │               └── Webhooks::GhlEventsJob
    │                     ├── contact.create/update/delete → Ghl::ContactSyncService
    │                     ├── conversation.message → Ghl::MessageSyncService
    │                     ├── conversation.status → MessageSyncService#sync_status
    │                     ├── app.installed/uninstalled → lifecycle handling
    │                     └── location.create/update → multi-tenant tracking
    │
    └── Admin Dashboard → SuperAdmin::GhlTenantsController
                            ├── Tenant list with filters
                            ├── Usage metrics + AI chart
                            ├── Plan management (upgrade/suspend/reactivate)
                            └── Usage reset
```

## Tiered Pricing

| Plan | Locations | Agents | AI Credits/mo | Price | Features |
|------|-----------|--------|---------------|-------|----------|
| **Starter** | 1 | 3 | 500 | $97/mo | Live chat, email, contact sync, basic reporting |
| **Growth** | 5 | 10 | 2,500 | $297/mo | + Hudley Copilot, automation rules, teams, advanced reporting |
| **Scale** | 25 | 50 | 10,000 | $697/mo | + Hudley Assistant, white-label, custom domain, API access |
| **Enterprise** | Unlimited | Unlimited | 50,000 | Custom | + Dedicated infrastructure, SLA, custom integrations |

All plans start with a **14-day free trial**.

## Key Files

### Models
- `app/models/ghl_subscription.rb` — Plan/pricing/usage tracking
- `app/models/concerns/ghl_plan_enforcement.rb` — Limit enforcement concern

### Services
- `app/services/ghl/workspace_provisioning_service.rb` — Auto-create workspace
- `app/services/ghl/contact_sync_service.rb` — Bidirectional contact sync
- `app/services/ghl/message_sync_service.rb` — Conversation/message sync
- `app/services/ghl/token_refresh_service.rb` — OAuth token refresh

### Controllers
- `app/controllers/ghl/callbacks_controller.rb` — OAuth callback (both flows)
- `app/controllers/webhooks/ghl_controller.rb` — Webhook receiver
- `app/controllers/super_admin/ghl_tenants_controller.rb` — Admin dashboard
- `app/controllers/api/v1/accounts/ghl/subscriptions_controller.rb` — Frontend API

### Jobs
- `app/jobs/webhooks/ghl_events_job.rb` — Event routing
- `app/jobs/ghl/contact_enrichment_job.rb` — Lazy contact enrichment
- `app/jobs/ghl/monthly_usage_reset_job.rb` — Monthly AI credit reset
- `app/jobs/integrations/ghl/refresh_tokens_job.rb` — Token refresh

### Database
- `db/migrate/20260202072500_create_ghl_subscriptions.rb`

### Admin Views
- `app/views/super_admin/ghl_tenants/index.html.erb` — Tenant list
- `app/views/super_admin/ghl_tenants/show.html.erb` — Tenant detail
- `app/views/super_admin/ghl_tenants/edit.html.erb` — Edit subscription

## Webhook Events Handled

| Event | Handler | Description |
|-------|---------|-------------|
| `contact.create` | ContactSyncService | Create DeskFlows contact from GHL |
| `contact.update` | ContactSyncService | Update contact attributes |
| `contact.delete` | ContactSyncService | Archive (soft-delete) contact |
| `InboundMessage` | MessageSyncService | Incoming message → create conversation |
| `OutboundMessage` | MessageSyncService | Outgoing message → append to conversation |
| `conversation.status` | MessageSyncService | Sync open/closed status |
| `app.installed` | GhlEventsJob | Log install, reactivate if needed |
| `app.uninstalled` | GhlEventsJob | Disable hook, suspend subscription |
| `location.create` | GhlEventsJob | Track new location, check limits |
| `location.update` | GhlEventsJob | Log location changes |

## API Endpoints

### GHL Subscription (Frontend)
```
GET    /api/v1/accounts/:id/ghl/subscription     → subscription + plans
GET    /api/v1/accounts/:id/ghl/subscription/usage → usage metrics
```

### Super Admin
```
GET    /super_admin/ghl_tenants           → tenant list
GET    /super_admin/ghl_tenants/:id       → tenant detail
GET    /super_admin/ghl_tenants/:id/edit  → edit form
PATCH  /super_admin/ghl_tenants/:id       → update
POST   /super_admin/ghl_tenants/:id/upgrade       → plan upgrade
POST   /super_admin/ghl_tenants/:id/suspend       → suspend
POST   /super_admin/ghl_tenants/:id/reactivate    → reactivate
POST   /super_admin/ghl_tenants/:id/reset_usage   → reset AI credits
```
