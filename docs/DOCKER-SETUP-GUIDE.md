# DeskFlow Docker Setup Guide

This guide covers a full Docker-based development setup for DeskFlow, including Rails, Vite, Sidekiq, Postgres, Redis, and Mailhog.

## Prerequisites

- Docker Desktop or OrbStack (Docker 24+ with Compose v2)
- Git (to clone the repo)

You do not need Ruby, Node.js, PostgreSQL, or Redis installed locally.

## Files Used By Docker Compose

- `.env` contains your base local configuration (works for non-Docker too).
- `.env.docker` overrides Docker-only values like service hostnames, passwords, and Mailhog settings.
- `docker-compose.yaml` wires services together and applies Docker-specific environment overrides.

## Quick Start

```bash
# 1. Copy base env file if you do not already have one
cp .env.example .env

# 2. Review Docker-specific overrides
sed -n '1,200p' .env.docker

# 3. Build images (first build is slow due to native gems)
docker compose build base rails vite

# 4. Start all services
docker compose up -d

# 5. Prepare the database
docker compose exec rails bundle exec rails db:deskflows_prepare

# 6. Open the app
open http://localhost:3000
```

## Service Overview

| Service | Port | Purpose |
| --- | --- | --- |
| `rails` | 3000 | Rails web + API |
| `vite` | 3036 | Frontend dev server |
| `sidekiq` | — | Background jobs |
| `postgres` | 5432 | Database (pgvector/pg16) |
| `redis` | 6379 | Cache + Sidekiq |
| `mailhog` | 8025 | Email UI |

## Environment Notes

- Docker uses service names (`postgres`, `redis`, `mailhog`) instead of `localhost`.
- `.env.docker` sets:
  - `POSTGRES_HOST=postgres`
  - `POSTGRES_PASSWORD=postgres`
  - `REDIS_URL=redis://:redis@redis:6379`
  - `SMTP_ADDRESS=mailhog`
- Keep `.env` for local (non-Docker) usage. Docker Compose merges `.env` with `.env.docker`.

## Common Commands

```bash
# Start/stop
docker compose up -d
docker compose down

# Logs
docker compose logs -f
docker compose logs -f rails

# Rails console
docker compose exec rails bundle exec rails console

# Run migrations
docker compose exec rails bundle exec rails db:migrate

# Run tests
docker compose exec rails bundle exec rspec

# Reset volumes (destructive)
docker compose down -v
```

## Database Preparation Task

DeskFlow uses a custom prepare task:

```bash
docker compose exec rails bundle exec rails db:deskflows_prepare
```

This task loads the schema and seeds only when needed, then runs migrations. It is safer for Docker and platform environments than `db:prepare`.

## Troubleshooting

### Postgres fails to start
- Ensure `POSTGRES_PASSWORD` is set in `.env.docker`.
- Check logs: `docker compose logs -f postgres`

### Redis connection errors
- Confirm `REDIS_URL` includes the password from `.env.docker`.
- Check logs: `docker compose logs -f redis`

### Vite not reachable from Rails
- Ensure `VITE_DEV_SERVER_HOST=vite` in the `rails` service.
- Ensure `VITE_DEV_SERVER_HOST=0.0.0.0` in the `vite` service.

### Rails boot errors after adding gems
- Rebuild: `docker compose build rails`
- Or restart: `docker compose up -d --build rails`

## Suggested First-Run Verification

```bash
docker compose ps
docker compose exec rails bundle exec rails runner "puts User.count"
docker compose exec rails bundle exec rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
```
