# DeskFlow Docker Dev Environment — Setup & Fixes

> **Ticket:** DSK-010
> **Author:** Avery 🛡️ (CTO)
> **Date:** 2026-02-01
> **Branch:** `avery/dsk-docker-setup`

---

## TL;DR

```bash
cp .env.example .env                         # Base config (if missing)
docker compose build base                    # Build the shared base image (~5-10 min first time)
docker compose build rails vite              # Build app images (fast — extends base)
docker compose up -d                         # Start everything
docker compose exec rails bundle exec rails db:deskflows_prepare   # DB setup
open http://localhost:3000                   # 🎉
```

Or just run the helper script:
```bash
./bin/docker-dev-setup
```

---

## Bugs Found & Fixed

### 🔴 Critical: Profile Inheritance Prevents All Services From Starting

**Problem:**
The `docker-compose.yaml` uses a YAML anchor (`&base`) for shared config. The `base` service correctly had `profiles: [build]` to prevent it from running directly. However, **YAML merge keys (`<<: *base`) propagate ALL keys**, including `profiles`. This meant `rails`, `sidekiq`, and `vite` all inherited `profiles: [build]` and would NOT start with `docker compose up`.

```yaml
# BEFORE (broken) — profiles inherited silently
base: &base
  profiles:
    - build
  # ...

rails:
  <<: *base          # ← inherits profiles: [build]
  # profiles NOT overridden → rails requires --profile build to start!
```

**Fix:** Explicitly override `profiles: []` on every child service:

```yaml
rails:
  <<: *base
  profiles: []       # ← now starts with plain `docker compose up`
```

**Impact:** Without this fix, `docker compose up` only starts postgres, redis, and mailhog — no app services.

---

### 🔴 Critical: Sidekiq Build Mismatch

**Problem:**
The `sidekiq` service inherited `build.dockerfile: ./docker/Dockerfile` (base image) from the anchor, but set `image: deskflows-rails:development`. This means building sidekiq would compile the *base* Dockerfile and tag it as the *rails* image, clobbering the actual rails build.

**Fix:** Added explicit `build.dockerfile: ./docker/dockerfiles/rails.Dockerfile` to sidekiq so it uses the same image as the rails service.

---

### 🟡 Medium: No Health Checks on Postgres/Redis

**Problem:**
The `rails.sh` entrypoint has a `pg_isready` loop, but Docker Compose's `depends_on` without health checks only waits for the *container* to start — not for the service inside to be ready. This creates race conditions.

**Fix:** Added proper `healthcheck` definitions to postgres and redis, and switched `depends_on` to use `condition: service_healthy`.

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 5s
    timeout: 5s
    retries: 10
```

---

### 🟡 Medium: Missing SMTP_PORT in .env.docker

**Problem:**
`.env.docker` set `SMTP_ADDRESS=mailhog` but not `SMTP_PORT`. The `.env` file defaults to `SMTP_PORT=1025` which is correct, but if someone sets a different port in `.env`, Docker wouldn't override it.

**Fix:** Added `SMTP_PORT=1025` to `.env.docker`.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  docker compose up                                   │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ postgres │  │  redis   │  │     mailhog      │   │
│  │  :5432   │  │  :6379   │  │  :1025 / :8025   │   │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │
│       │              │                 │              │
│  ┌────┴──────────────┴─────────────────┴──────────┐  │
│  │              rails (:3000)                      │  │
│  │   entrypoint: rails.sh → waits for pg → boot   │  │
│  └────┬───────────────────────────────────────────┘  │
│       │                                              │
│  ┌────┴──────────┐  ┌────────────────────────────┐   │
│  │   sidekiq     │  │      vite (:3036)          │   │
│  │  (background  │  │   frontend dev server      │   │
│  │   jobs)       │  │   (Vue.js hot reload)      │   │
│  └───────────────┘  └────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Build Chain

```
docker/Dockerfile          →  deskflows:development       (base: Ruby 3.4.4 + Node 24 + gems + pnpm)
  └─ rails.Dockerfile      →  deskflows-rails:development (extends base, adds entrypoint)
  └─ vite.Dockerfile       →  deskflows-vite:development  (extends base, adds entrypoint)
```

**Important:** The base image MUST be built first. `rails.Dockerfile` and `vite.Dockerfile` both start with `FROM deskflows:development`.

---

## Service Reference

| Service    | Image                          | Port(s)        | Depends On           | Purpose                          |
|------------|-------------------------------|----------------|----------------------|----------------------------------|
| `base`     | `deskflows:development`       | —              | —                    | Build target only (never runs)   |
| `rails`    | `deskflows-rails:development` | 3000           | postgres, redis, vite, mailhog | Rails API + web server |
| `sidekiq`  | `deskflows-rails:development` | —              | postgres, redis, mailhog | Background job processor |
| `vite`     | `deskflows-vite:development`  | 3036           | —                    | Vue.js frontend dev server       |
| `postgres` | `pgvector/pgvector:pg16`      | 5432           | —                    | Database (with pgvector)         |
| `redis`    | `redis:alpine`                | 6379           | —                    | Cache + Sidekiq queue backend    |
| `mailhog`  | `mailhog/mailhog`             | 1025, 8025     | —                    | Email catch-all (UI at :8025)    |

---

## Database: `deskflows_prepare`

DeskFlow uses a custom Rake task instead of `rails db:prepare`:

```bash
docker compose exec rails bundle exec rails db:deskflows_prepare
```

**What it does** (see `lib/tasks/db_enhancements.rake`):
1. Connects to each configured database
2. If `ar_internal_metadata` table doesn't exist → loads schema + seeds
3. Runs migrations regardless
4. If database doesn't exist at all → runs full `db:setup` (create + schema + seed)

This is more resilient than `db:prepare` for containerized/PaaS environments.

---

## Environment Variable Precedence

Docker Compose loads env files in order — later files override earlier ones:

```
.env              ← base config (POSTGRES_HOST=localhost, REDIS_URL=redis://localhost:6379)
.env.docker       ← Docker overrides (POSTGRES_HOST=postgres, REDIS_URL=redis://:redis@redis:6379)
environment:      ← compose inline overrides (VITE_DEV_SERVER_HOST, etc.)
```

**Key overrides in `.env.docker`:**

| Variable            | `.env` (local)                      | `.env.docker` (Docker)                    |
|---------------------|-------------------------------------|-------------------------------------------|
| `POSTGRES_HOST`     | `localhost`                         | `postgres` (service name)                 |
| `POSTGRES_PASSWORD` | *(empty)*                           | `postgres`                                |
| `REDIS_URL`         | `redis://localhost:6379`            | `redis://:redis@redis:6379`               |
| `SMTP_ADDRESS`      | *(empty)*                           | `mailhog`                                 |
| `SMTP_PORT`         | `1025`                              | `1025`                                    |

---

## Common Commands

```bash
# --- Lifecycle ---
docker compose up -d                    # Start all services
docker compose down                     # Stop all services
docker compose down -v                  # Stop + destroy volumes (full reset)
docker compose restart rails            # Restart just rails

# --- Logs ---
docker compose logs -f                  # All services
docker compose logs -f rails            # Just rails
docker compose logs -f vite             # Just vite (frontend build errors)

# --- Rails ---
docker compose exec rails bundle exec rails console
docker compose exec rails bundle exec rails db:migrate
docker compose exec rails bundle exec rails db:deskflows_prepare
docker compose exec rails bundle exec rspec

# --- Building ---
docker compose build base               # Rebuild base (after Gemfile/package.json changes)
docker compose build rails vite          # Rebuild app images
docker compose up -d --build rails       # Rebuild + restart rails in one command

# --- Debugging ---
docker compose ps                        # Service status
docker compose exec rails bash           # Shell into rails container
docker compose exec postgres psql -U postgres -d deskflows   # Direct DB access
```

---

## Troubleshooting

### `deskflows:development` image not found

The base image hasn't been built yet:
```bash
docker compose build base
```

### `docker compose up` only starts postgres/redis/mailhog

You're hitting the profile inheritance bug. Make sure `docker-compose.yaml` has `profiles: []` on `rails`, `sidekiq`, and `vite` services (this branch fixes it).

### Postgres connection refused on startup

Check that postgres is healthy:
```bash
docker compose ps postgres
docker compose logs postgres
```

The rails entrypoint (`docker/entrypoints/rails.sh`) also has a `pg_isready` retry loop, but the health check is more reliable.

### Port 3000/5432/6379 already in use

Something is running locally on those ports:
```bash
lsof -i :3000
lsof -i :5432
lsof -i :6379
# Kill the process or change port mappings in docker-compose.yaml
```

### Vite assets not loading in Rails

Verify `VITE_DEV_SERVER_HOST=vite` is set in the rails service environment (it connects to the vite container by service name). Check vite logs:
```bash
docker compose logs -f vite
```

### Slow startup (entrypoints run bundle install / pnpm install)

The entrypoint scripts run `bundle install` (rails.sh) and `pnpm install --force` (vite.sh) on every container start. This ensures the mounted volume stays in sync with Gemfile/package.json changes. First start after a build is slower; subsequent starts are fast because dependencies are cached in named volumes.

---

## Non-Docker Alternative

If you prefer running without Docker, see `docs/LOCAL_DEV_SETUP.md` (Non-Docker Setup section).

**Requirements:** Ruby 3.4.4, Node.js 24.13.0, pnpm 10+, PostgreSQL 16+ with pgvector, Redis 7+.

```bash
make setup    # bundle install + pnpm install
make db       # runs db:deskflows_prepare
make run      # starts all services via overmind
```

---

## Prerequisites for Docker

- **Docker Engine** 24+ with **Compose v2** (Docker Desktop or OrbStack on macOS)
- ~4GB disk space for images
- ~2GB RAM allocated to Docker

### macOS (OrbStack — recommended)

```bash
brew install orbstack
# Then: open OrbStack → it handles everything
```

### macOS (Docker Desktop)

```bash
brew install --cask docker
# Then: open Docker.app → ensure Engine is running
```

### Linux

```bash
# Follow: https://docs.docker.com/engine/install/
# Then: sudo systemctl start docker
```

---

*This document was generated during the DSK-010 Docker dev environment audit.*
