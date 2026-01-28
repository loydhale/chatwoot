# DeskFlow Development Kanban

> Last updated: 2025-01-27 | Current sprint: Environment Setup & First Run

---

## 📋 Backlog
*Ideas and future work — not yet prioritized*

| Task | Notes |
|------|-------|
| Proper logo design | Replace placeholder SVGs with real branding |
| Custom domain support | Let agencies use their own domains |
| GHL Marketplace submission | App store listing, screenshots, copy |
| Usage analytics dashboard | Show AI usage, ticket volume, response times |
| Email template customization | Per-account email branding |
| Mobile app wrapper | PWA or native shell |

---

## 📌 Up Next
*Prioritized and ready to pick up*

| Task | Priority | Notes |
|------|----------|-------|
| Per-account white-labeling | HIGH | Agencies customize logo/colors for their clients |
| GHL OAuth integration | HIGH | SSO from GHL dashboard |
| AI usage metering | MEDIUM | Track Atlas responses for billing |
| Knowledge base import tool | MEDIUM | Bulk import from existing docs |

---

## 🔨 In Progress
*Currently being worked on*

| Task | Started | Status |
|------|---------|--------|
| Dev environment setup | 2025-01-27 | ✅ Homebrew installed |
| | | ✅ OrbStack/Docker installed |
| | | ⏳ Docker build timing out (grpc compile) |

---

## 🚧 Blocked
*Stuck waiting on something*

| Task | Blocker | Waiting On |
|------|---------|------------|
| Docker image build | grpc gem compile takes 10+ min | Need longer timeout or pre-built image |

---

## ✅ Done
*Completed work*

| Task | Completed | Notes |
|------|-----------|-------|
| Fork Chatwoot repo | 2025-01-26 | loydhale/chatwoot |
| Rebrand → DeskFlow | 2025-01-26 | ~1,200 files updated |
| Rebrand Captain → Atlas | 2025-01-26 | AI assistant renamed |
| Create placeholder logos | 2025-01-26 | SVG logos (light/dark/thumb) |
| Update all locale files | 2025-01-26 | 703 files, all languages |
| Update Vue/JS components | 2025-01-26 | 144 files |
| Update Ruby files | 2025-01-26 | 187 files |
| Update spec/test files | 2025-01-26 | 116 files |
| Documentation (README, BRANDING) | 2025-01-26 | New docs created |

---

## 🎯 Milestones

### M1: First Run ⬅️ *Current*
- [x] Rebrand complete
- [ ] Dev environment working
- [ ] App boots successfully
- [ ] Can create test account

### M2: GHL Integration
- [ ] OAuth flow working
- [ ] SSO from GHL dashboard
- [ ] Webhook receivers set up

### M3: White-Label Features
- [ ] Per-account branding UI
- [ ] Custom logo/color upload
- [ ] Subdomain or custom domain routing

### M4: AI Billing
- [ ] Usage tracking in DB
- [ ] Metering API for GHL
- [ ] Billing dashboard

### M5: Launch Ready
- [ ] Production deployment
- [ ] GHL Marketplace listing
- [ ] Documentation site

---

## 📝 Notes

**Tech Stack:**
- Rails 7 + Ruby 3.2
- Vue.js 3 frontend
- PostgreSQL + pgvector
- Redis
- Sidekiq for jobs

**Key Decisions:**
- Product name: DeskFlow
- AI assistant: Atlas
- Preserved API compatibility with `chatwoot` names

---

*Updated by Paul 🛠️*
