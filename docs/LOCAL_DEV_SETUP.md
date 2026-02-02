# DeskFlow — Local Development Setup

> Getting DeskFlow running locally for development using Docker Compose.

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| **Docker** | 24+ | OrbStack recommended on macOS |
| **Docker Compose** | v2+ | Included with Docker Desktop / OrbStack |
| **Git** | 2.30+ | For cloning the repo |

> **Note:** You do NOT need Ruby, Node.js, or PostgreSQL installed locally. Docker handles everything.

---

## Quick Start

```bash
# 1. Clone and enter the repo
git clone git@github.com:loydhale/deskflows.git /path/to/supportflow
cd /path/to/supportflow
git checkout fix/local-dev-setup

# 2. Copy the environment file
cp .env.example .env

# 3. Build the base Docker image (first time takes ~5-10 min)
docker compose build base

# 4. Build the rails and vite service images
docker compose build rails vite

# 5. Start all services
docker compose up -d

# 6. Create and migrate the database
docker compose exec rails bundle exec rails db:deskflows_prepare

# 7. Open in browser
open http://localhost:3000
```

---

## Services

| Service | Port | Description |
|---------|------|-------------|
| **rails** | `3000` | Rails API + web server |
| **vite** | `3036` | Vite dev server (Vue.js hot reload) |
| **sidekiq** | — | Background job processor |
| **postgres** | `5432` | PostgreSQL 16 with pgvector |
| **redis** | `6379` | Cache + Sidekiq queue backend |
| **mailhog** | `8025` | Email testing UI (catches all outgoing mail) |

---

## Environment Variables

The Docker Compose file automatically overrides these for the containerized services:

| Variable | Docker Value | Notes |
|----------|-------------|-------|
| `POSTGRES_HOST` | `postgres` | Service name in docker-compose |
| `POSTGRES_USERNAME` | `postgres` | Default postgres user |
| `REDIS_URL` | `redis://redis:6379` | Service name in docker-compose |
| `RAILS_ENV` | `development` | — |

Your `.env` file keeps `localhost` values for the local (non-Docker) setup. Docker Compose overrides them with the `environment:` block.

### GHL OAuth (Optional)

To test the GHL marketplace integration, add these to `.env`:

```bash
GHL_CLIENT_ID=your_client_id
GHL_CLIENT_SECRET=your_client_secret
```

Get these from the [GHL Developer Portal](https://marketplace.gohighlevel.com/apps).

---

## Common Commands

```bash
# Start everything
docker compose up -d

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f rails

# Rails console
docker compose exec rails bundle exec rails console

# Run migrations
docker compose exec rails bundle exec rails db:migrate

# Run tests
docker compose exec rails bundle exec rspec

# Stop everything
docker compose down

# Full reset (nuke volumes)
docker compose down -v
```

---

## Build Details

The Docker setup uses a multi-stage build:

1. **Base image** (`docker/Dockerfile`) — Ruby 3.4.4 + Node 24 + pnpm + all gems + npm packages
2. **Rails image** (`docker/dockerfiles/rails.Dockerfile`) — Extends base, runs entrypoint that waits for Postgres
3. **Vite image** (`docker/dockerfiles/vite.Dockerfile`) — Extends base, runs `bin/vite dev` for frontend hot-reload

The base image build is the slowest part (~5-10 min) due to native gem compilation (grpc, sassc, pg, etc.). Subsequent builds are cached.

---

## Troubleshooting

### "deskflows:development" image not found
Build the base image first:
```bash
docker compose build base
```

### Database connection errors
Make sure Postgres is running and the env overrides are correct:
```bash
docker compose ps  # Check postgres is healthy
docker compose exec rails env | grep POSTGRES  # Verify env vars
```

### Vite not connecting
Check that the vite service is running:
```bash
docker compose logs vite
```
The rails service expects `VITE_DEV_SERVER_HOST=vite` which is set in docker-compose.yaml.

### Native gem compilation is slow
The base image compiles grpc, sassc, pg, nokogiri, etc. from source. This is normal for the first build. Subsequent builds use the Docker cache.

### Port conflicts
If port 3000, 5432, or 6379 are in use:
```bash
# Check what's using the port
lsof -i :3000
# Kill it or change the port mapping in docker-compose.yaml
```

---

## Non-Docker Setup (Alternative)

If you prefer running without Docker:

### Requirements
- Ruby 3.4.4 (via rbenv or asdf)
- Node.js 24.13.0 (via nvm or fnm)
- pnpm 10+
- PostgreSQL 16+ with pgvector extension
- Redis 7+

### Steps
```bash
# Install dependencies
make setup  # runs bundle install + pnpm install

# Create database
make db

# Start all services (requires overmind)
make run
# Or: foreman start -f Procfile.dev
```

---

*Last updated: 2026-01-30*
