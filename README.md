# DeskFlow

<div align="center">
  <h3>🚀 White-Label AI Support Platform for Agencies</h3>
  <p>Transform your agency's support operations with intelligent automation, powered by Atlas AI</p>
</div>

---

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built on DeskFlows](https://img.shields.io/badge/Built%20on-DeskFlows-blue)](https://github.com/deskflows/deskflows)
[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red)](https://www.ruby-lang.org)
[![Vue.js](https://img.shields.io/badge/Vue.js-3.x-green)](https://vuejs.org)

</div>

---

## 📖 What is DeskFlow?

**DeskFlow** is a powerful customer support platform purpose-built for agencies—especially those on [GoHighLevel (GHL)](https://www.gohighlevel.com/). It enables agencies to offer **white-labeled support services** to their clients, complete with RAG-powered AI assistance from **Atlas**, our intelligent assistant.

> DeskFlow is a fork of [DeskFlows](https://github.com/deskflows/deskflows), the open-source customer engagement platform, enhanced with agency-specific features and deep GHL Marketplace integration.

### Who is DeskFlow for?

- **GHL Agencies** wanting to offer branded support tools to clients
- **SaaS Companies** needing white-label customer support
- **Managed Service Providers** providing help desk solutions
- **Any business** wanting AI-powered support automation

---

## ✨ Features

### 🎨 White-Label Ready
- Full branding customization at platform and per-account levels
- Custom logos, colors, and CSS per agency/client
- Subdomain and custom domain support
- Branded email templates

### 🤖 Atlas AI Assistant
- RAG-powered responses from your knowledge base
- Document ingestion (URLs, PDFs, text files)
- **Co-pilot mode** for agent assistance
- Automatic ticket resolution
- Customizable personality and tone per account
- Usage metering for billing

### 📬 Omni-Channel Inbox
- Email integration
- Website live chat widget
- API integrations
- Unified conversation view
- Team collaboration tools

### 📚 Knowledge Base
- Self-service help center
- AI-powered search
- Article categories and organization
- Public and private articles
- Customizable branding

### 🔗 GHL Marketplace Integration
- OAuth authentication (SSO from GHL)
- Subscription billing ($29-$199/mo tiers)
- Usage-based AI metering
- Agency rebilling support
- Webhook receivers

### 📊 Analytics & Reporting
- Conversation metrics
- Agent performance
- Response times
- AI usage tracking
- Customer satisfaction scores

---

## 🖼️ Screenshots

> *Coming soon — Screenshots of the dashboard, widget, and Atlas AI in action*

| Dashboard | Chat Widget | Atlas AI |
|:---------:|:-----------:|:--------:|
| ![Dashboard](docs/screenshots/dashboard-placeholder.png) | ![Widget](docs/screenshots/widget-placeholder.png) | ![Atlas](docs/screenshots/atlas-placeholder.png) |

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version |
|-------------|---------|
| Ruby | 3.2+ |
| Node.js | 24+ |
| PostgreSQL | 15+ (with pgvector extension) |
| Redis | 7+ |
| Docker | Latest (optional) |

### Option 1: Docker Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/loydhale/deskflows.git deskflow
cd deskflow

# Copy environment file
cp .env.example .env

# Start with Docker Compose
docker-compose up -d

# Access at http://localhost:3000
```

### Option 2: Manual Development Setup

```bash
# Clone the repository
git clone https://github.com/loydhale/deskflows.git deskflow
cd deskflow

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
pnpm install

# Setup environment
cp .env.example .env
# Edit .env with your database credentials

# Setup database
rails db:prepare

# Start development server
pnpm run dev

# Access at http://localhost:3000
```

### First-Time Setup

1. Navigate to `http://localhost:3000`
2. Create your super admin account
3. Set up your first inbox (chat widget, email, or API)
4. Configure Atlas AI with your knowledge base
5. Customize branding in Settings

---

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DATABASE=deskflow_production
POSTGRES_USERNAME=deskflow
POSTGRES_PASSWORD=your_secure_password

# Redis
REDIS_URL=redis://localhost:6379

# Application
SECRET_KEY_BASE=your_secret_key_here
FRONTEND_URL=https://your-domain.com
DEFAULT_LOCALE=en

# Email (SMTP)
SMTP_ADDRESS=smtp.your-provider.com
SMTP_PORT=587
SMTP_USERNAME=your_email@domain.com
SMTP_PASSWORD=your_smtp_password
MAILER_SENDER_EMAIL=support@your-domain.com

# AI (Atlas)
OPENAI_API_KEY=sk-your-openai-key
ATLAS_ENABLED=true

# GHL Integration (Optional)
GHL_CLIENT_ID=your_ghl_client_id
GHL_CLIENT_SECRET=your_ghl_client_secret
GHL_MARKETPLACE_URL=https://marketplace.gohighlevel.com
```

### Atlas AI Configuration

Atlas can be configured per-account or globally:

| Setting | Description | Default |
|---------|-------------|---------|
| `ATLAS_ENABLED` | Enable AI features | `true` |
| `ATLAS_MODEL` | OpenAI model to use | `gpt-4o` |
| `ATLAS_TEMPERATURE` | Response creativity (0-1) | `0.7` |
| `ATLAS_MAX_TOKENS` | Max response length | `500` |

### White-Label Branding

Customize your deployment:

1. **Platform-level**: Replace assets in `/public` and modify styles in `/app/javascript`
2. **Per-account**: Use the Admin → Settings → Branding panel

---

## 📁 Project Structure

```
deskflow/
├── app/                      # Rails application
│   ├── controllers/          # API & web controllers
│   ├── javascript/           # Vue.js frontend
│   │   ├── dashboard/        # Agent dashboard SPA
│   │   ├── widget/           # Embeddable chat widget
│   │   └── portal/           # Knowledge base portal
│   ├── models/               # ActiveRecord models
│   ├── services/             # Business logic
│   └── views/                # Email templates, etc.
├── config/                   # Rails configuration
├── db/                       # Database migrations
├── docker/                   # Docker configuration
├── enterprise/               # Enterprise features (Atlas AI)
├── lib/                      # Shared libraries
├── public/                   # Static assets (logos, etc.)
└── spec/                     # RSpec test suite
```

---

## 🔧 Development

### Running Tests

```bash
# All tests
bundle exec rspec

# Specific test file
bundle exec rspec spec/models/user_spec.rb

# JavaScript tests
pnpm test
```

### Code Quality

```bash
# Ruby linting
bundle exec rubocop

# JavaScript linting
pnpm lint
```

### Database Migrations

```bash
rails db:migrate           # Run pending migrations
rails db:rollback          # Rollback last migration
rails db:seed              # Seed development data
```

---

## 🚢 Deployment

### Production Checklist

- [ ] Set strong `SECRET_KEY_BASE`
- [ ] Configure SMTP for emails
- [ ] Set up SSL certificates
- [ ] Configure Redis for production
- [ ] Set up background job workers (Sidekiq)
- [ ] Configure CDN for assets (optional)
- [ ] Set up monitoring and logging

### Docker Production

```bash
docker-compose -f docker-compose.production.yml up -d
```

### Platform Guides

- [Deploy to Railway](docs/deployment/railway.md) *(coming soon)*
- [Deploy to Render](docs/deployment/render.md) *(coming soon)*
- [Deploy to AWS](docs/deployment/aws.md) *(coming soon)*

---

## 📄 License

DeskFlow is built on [DeskFlows](https://github.com/deskflows/deskflows), licensed under the MIT License.

```
MIT License

Copyright (c) 2017-2024 DeskFlows Inc.
Copyright (c) 2025 GrowLocals.ai (DeskFlow modifications)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 🙏 Attribution & Thanks

DeskFlow is proudly built on [**DeskFlows**](https://www.deskflows.com), the excellent open-source customer engagement platform. We extend our sincere gratitude to the DeskFlows team and all its contributors for creating such a solid foundation.

**Key upstream features we build upon:**
- Omni-channel inbox architecture
- Vue.js dashboard and widget
- Rails API backend
- Enterprise Captain AI (now Atlas)

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📞 Support

- **Documentation**: [Coming Soon]
- **Issues**: [GitHub Issues](https://github.com/loydhale/deskflows/issues)
- **Email**: support@growlocals.ai

---

<div align="center">
  <p>Built with ❤️ by <a href="https://growlocals.ai">GrowLocals.ai</a></p>
  <p>Powered by <a href="https://www.deskflows.com">DeskFlows</a></p>
</div>
