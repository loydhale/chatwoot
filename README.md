# DeskFlow

**White-label AI Support Platform for Agencies**

DeskFlow is a powerful customer support platform built for agencies using GoHighLevel (GHL). It enables agencies to provide white-labeled support services to their location clients, complete with RAG-powered AI assistance.

## ✨ Features

- **White-Label Ready** — Full branding customization at platform and per-account levels
- **AI-Powered Support** — Atlas AI assistant for automated responses using RAG
- **Knowledge Base** — Self-service help center with AI-powered search
- **Omni-Channel Inbox** — Email, chat widget, and API integrations
- **GHL Marketplace Ready** — Easy installation and billing integration
- **Usage-Based AI Billing** — Track and bill AI usage per response

## 🏗️ Architecture

DeskFlow is built on the excellent [Chatwoot](https://github.com/chatwoot/chatwoot) open-source platform, enhanced with:

- Per-account white-labeling capabilities
- GHL OAuth and SSO integration
- AI usage metering for marketplace billing
- Custom "Atlas" AI assistant branding

## 🚀 Quick Start

### Prerequisites

- Ruby 3.2+
- Node.js 24+
- PostgreSQL 15+ with pgvector extension
- Redis 7+

### Development Setup

```bash
# Clone the repository
git clone https://github.com/loydhale/chatwoot.git deskflow
cd deskflow

# Install dependencies
bundle install
pnpm install

# Setup database
rails db:prepare

# Start development server
pnpm run dev
```

### Docker Setup

```bash
docker-compose up -d
```

## 📊 GHL Marketplace Integration

DeskFlow integrates with the GoHighLevel Marketplace for:

- **OAuth Authentication** — Seamless SSO from GHL
- **Subscription Billing** — Tiered pricing ($29-$199/mo)
- **Usage Metering** — AI responses billed per use
- **Agency Rebilling** — Markup support for resellers

## 🤖 Atlas AI Assistant

Atlas is DeskFlow's AI assistant, powered by:

- RAG-based responses from your knowledge base
- Document ingestion (URLs, PDFs)
- Co-pilot mode for agent assistance
- Automatic ticket resolution
- Customizable personality per account

## 📁 Project Structure

```
deskflow/
├── app/                    # Rails application
│   ├── controllers/        # API endpoints
│   ├── javascript/         # Vue.js frontend
│   │   ├── dashboard/      # Agent dashboard
│   │   └── widget/         # Chat widget
│   ├── models/             # Data models
│   └── views/              # Email templates
├── config/                 # Configuration
├── enterprise/             # Enterprise features (Captain/Atlas)
├── public/                 # Static assets
└── spec/                   # Tests
```

## 🎨 Branding

### Platform Level
Modify assets in `/public` and styles in `/app/javascript`.

### Per-Account
Each agency can customize:
- Logo and colors
- AI assistant name and avatar
- Help center branding
- Custom CSS

## 📄 License

DeskFlow is built on [Chatwoot](https://github.com/chatwoot/chatwoot), licensed under MIT.

**Original Chatwoot License:**
```
MIT License - Copyright (c) 2017-2024 Chatwoot Inc.
```

DeskFlow modifications are also MIT licensed.

## 🙏 Attribution

DeskFlow is proudly built on [Chatwoot](https://www.chatwoot.com), the open-source customer engagement platform. We thank the Chatwoot team for their excellent work.

---

Built with ❤️ by [GrowLocals.ai](https://growlocals.ai)
