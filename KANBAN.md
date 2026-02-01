# DeskFlows.ai — Development Kanban

> Hudley.ai = AI function name
> Priority: Rebrand → Docker boot → GHL completion → Marketplace

---

## 🔨 In Progress

| # | Card | Branch | Agent | Status |
|---|------|--------|-------|--------|

---

## 📌 Up Next (Priority Order)

### P0 — Rebrand & Boot
| # | Card | Dependencies | Notes |
|---|------|-------------|-------|
| 1 | Rebrand DeskFlow → DeskFlows | None | Update all instances: DeskFlow → DeskFlows, deskflow → deskflows, Atlas → Hudley. Package names, locales, Vue components, Ruby files, docs, URLs. |
| 2 | Rebrand Atlas → Hudley | Card #1 | AI assistant rename across all files. Captain was already → Atlas, now Atlas → Hudley. |
| 3 | Docker full boot verification | None (parallel) | Run docker compose up, fix any errors, verify Rails + Vite + Sidekiq all respond |
| 4 | Database setup & seed | Card #3 | Run db:deskflows_prepare, create test account, verify login flow |

### P1 — GHL Integration
| # | Card | Dependencies | Notes |
|---|------|-------------|-------|
| 5 | GHL OAuth end-to-end test | Card #3, #4 | Create GHL dev app, test full OAuth flow |
| 6 | Token refresh Sidekiq job | Card #5 | Proactively refresh GHL tokens before 24h expiry |
| 7 | Webhook receiver | Card #5 | POST /api/v1/webhooks/ghl endpoint + signature verification |
| 8 | Contact sync service | Card #7 | Bidirectional contact sync between DeskFlows and GHL |
| 9 | Message sending via GHL API | Card #8 | Send SMS/email through GHL from DeskFlows conversations |
| 10 | GHL Vue.js settings page | Card #5 | Dedicated frontend for GHL integration config |

### P2 — Marketplace Readiness
| # | Card | Dependencies | Notes |
|---|------|-------------|-------|
| 11 | Production deployment | Card #5 | Deploy to Render/Railway + deskflows.ai domain + SSL |
| 12 | Legal docs | None | Privacy policy + Terms of Service pages |
| 13 | Real logo design | None | Replace placeholder SVGs with proper branding (512x512 PNG) |
| 14 | App screenshots | Card #11 | 3-5 screenshots for marketplace listing |
| 15 | GHL Marketplace submission | Card #11-14 | Submit to marketplace for review |

### P3 — White-Label & Billing
| # | Card | Dependencies | Notes |
|---|------|-------------|-------|
| 16 | Per-account white-labeling | Card #11 | Agencies customize logo/colors for their clients |
| 17 | Custom domain routing | Card #16 | Agencies use their own domains |
| 18 | AI usage metering | Card #11 | Track Hudley AI responses for billing |

---

## ✅ Done

| # | Card | Notes |
|---|------|-------|
| — | DeskFlows → DeskFlow rebrand | 1,200+ files (needs update to DeskFlows) |
| — | Captain → Atlas rebrand | All files (needs update to Hudley) |
| — | GHL OAuth backend | 90% — routes, controllers, token storage |
| — | Docker setup | 80% — compose, Dockerfiles, env overrides |
| — | Documentation | LOCAL_DEV_SETUP.md, WHATS_LEFT.md, BRANDING.md |
