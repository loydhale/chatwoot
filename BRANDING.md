# DeskFlow Branding Guide

> Reference document for the DeskFlow rebrand from Chatwoot

---

## 🎯 Brand Names

| Original | DeskFlow Name | Context |
|----------|---------------|---------|
| Chatwoot | DeskFlow | Product name |
| chatwoot | deskflow | Code references, URLs |
| CHATWOOT | DESKFLOW | Environment variables |
| Captain | Atlas | AI Assistant |
| captain | atlas | Code references |
| CAPTAIN | ATLAS | Environment variables |

---

## 💡 Naming Rationale

### DeskFlow
- **Clean & Professional** — Works for B2B SaaS
- **Descriptive** — Implies workflow automation for support desks
- **Memorable** — Easy to spell, say, and remember
- **Agency-Friendly** — Neutral enough for white-labeling

### Atlas
- **Strong & Reliable** — Like the Greek Titan who held up the sky
- **Supportive** — Conveys foundation and assistance
- **Professional yet Friendly** — Approachable for users
- **Distinct** — Different from competitors (Copilot, Assistant, Helper, etc.)

---

## 🎨 Brand Colors

*Based on GrowLocals.ai brand guidelines*

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#1F93FF` | Buttons, links, accents |
| Primary Dark | `#0070DD` | Hover states |
| Success | `#10B981` | Positive actions |
| Warning | `#F59E0B` | Warnings, alerts |
| Error | `#EF4444` | Errors, destructive actions |
| Neutral | `#64748B` | Secondary text |
| Background | `#FFFFFF` | Light mode background |
| Background Dark | `#0F172A` | Dark mode background |

---

## 📁 Rebranded Files Summary

The rebrand affected ~1,200 files across the codebase:

### ✅ Completed

| Category | Files Changed | Notes |
|----------|---------------|-------|
| **Locale/i18n files** | 703 | All language translations |
| **Vue/JS components** | 144 | Dashboard, widget, portal |
| **Ruby files** | 187 | Models, controllers, services |
| **Spec/test files** | 116 | RSpec tests |
| **Config files** | 42 | Application config |
| **Documentation** | 8 | README, guides |
| **Assets** | Varies | Logos (placeholder SVGs) |

### 📍 Key File Locations

```
/public/
├── brand-assets/
│   ├── logo.svg              # Main logo
│   ├── logo-dark.svg         # Dark mode logo
│   └── logo-thumbnail.svg    # Favicon/thumbnail
├── favicon.ico
└── apple-touch-icon.png

/config/
├── application.rb            # App name configuration
└── locales/                   # Server-side i18n

/app/javascript/
├── dashboard/                 # Agent dashboard branding
├── widget/                    # Chat widget branding
└── shared/                    # Common components
```

---

## 🔧 Customization Points

### Platform Level (Global)

| What | Where | How |
|------|-------|-----|
| Logo | `/public/brand-assets/` | Replace SVG files |
| Favicon | `/public/favicon.ico` | Replace ICO file |
| Colors | CSS variables | Edit in stylesheets |
| App Name | `config/application.rb` | Change module name |
| Email Footer | Mailer templates | Edit views |

### Per-Account (Multi-tenant)

Each agency/account can customize:

| Setting | Description |
|---------|-------------|
| Logo | Upload custom logo |
| Primary Color | Accent color for UI |
| Widget Color | Chat widget theme |
| AI Assistant Name | Rename Atlas |
| Help Center Branding | Portal customization |
| Email Templates | Per-account email styles |

---

## 📋 API Compatibility

To maintain backward compatibility with existing integrations:

| Area | Behavior |
|------|----------|
| API Endpoints | Preserved as `/api/v1/...` |
| SDK Names | Documentation updated, code unchanged |
| Webhooks | Same payload structure |
| Database | Schema unchanged |

---

## 📜 License Attribution

**Required:** MIT License requires attribution to original authors.

All distributions must include:

```
DeskFlow is built on Chatwoot (https://github.com/chatwoot/chatwoot)
Copyright (c) 2017-2024 Chatwoot Inc.
Licensed under MIT License
```

This is included in:
- README.md
- LICENSE file  
- Application footer (recommended)

---

## 🚧 Outstanding Items

| Item | Status | Notes |
|------|--------|-------|
| Production logo design | TODO | Replace placeholder SVGs |
| Brand style guide PDF | TODO | For agency partners |
| Email template designs | TODO | Match brand guidelines |
| Marketing website | TODO | Landing page for DeskFlow |

---

## 📞 Contact

For branding questions or assets:
- **GrowLocals.ai**: [growlocals.ai](https://growlocals.ai)

---

*Last updated: January 2025*
