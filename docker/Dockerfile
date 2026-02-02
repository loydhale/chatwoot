# =============================================================================
# DeskFlows Production Dockerfile — Multi-stage, memory-optimized
# Target: Render Starter pipeline (2 CPU / 8 GB RAM)
#
# Memory budget per stage (must stay under 8 GB total):
#   Stage 1 (gem-builder):   ~2 GB peak  (grpc, nokogiri native compilation)
#   Stage 2 (asset-builder): ~3-4 GB peak (pnpm install + Rails + Vite build)
#   Stage 3 (final):         copy only — negligible
#
# If builds still OOM, enable the Performance pipeline tier in Render
# Dashboard → Workspace Settings → Build Pipeline → Performance (16 CPU / 64 GB).
# =============================================================================

# =============================================================================
# Stage 0: Node binary source
# =============================================================================
FROM node:24-alpine AS node

# =============================================================================
# Stage 1: Gem builder — compiles native extensions in isolation
# Once this stage completes, its peak memory is freed before Stage 2 starts
# (Stage 2 depends on Stage 1 via COPY --from, so BuildKit serializes them).
# =============================================================================
FROM ruby:3.4.4-alpine3.21 AS gem-builder

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16
ENV BUNDLE_PATH="/gems"

# build-base = gcc + g++ + make + musl-dev + binutils (no need to list them individually)
RUN apk update && apk add --no-cache \
  build-base \
  linux-headers \
  openssl-dev \
  postgresql-dev \
  vips \
  xz \
  git \
  && gem install bundler -v "$BUNDLER_VERSION"

WORKDIR /app
COPY Gemfile Gemfile.lock ./

# Limit parallel gem compilation to 2 jobs to cap peak memory
RUN bundle config set without 'development test' \
  && bundle install -j 2 -r 3

# Strip gem cache + compiled C artifacts to slim the layer
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete

# =============================================================================
# Stage 2: Asset builder — node deps + vite/sprockets compilation
# Gems are pre-built; we COPY them in from Stage 1 (no native compilation).
# =============================================================================
FROM ruby:3.4.4-alpine3.21 AS asset-builder

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}
ENV BUNDLER_VERSION=2.5.16
ENV BUNDLE_PATH="/gems"

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}

# ── Memory optimizations ─────────────────────────────────────────────────────
# Cap Node.js V8 heap at 768 MB (Vite + Rollup peak). Down from 1024 to leave
# headroom for Ruby + Docker daemon within the 8 GB pipeline limit.
ARG NODE_OPTIONS="--max-old-space-size=768 --openssl-legacy-provider"
ENV NODE_OPTIONS=${NODE_OPTIONS}

# Reduce glibc per-thread memory arenas (default = 8 × cores = 16 on Starter).
# With MALLOC_ARENA_MAX=2, fragmented free memory is reclaimed much faster.
ENV MALLOC_ARENA_MAX=2

# Slow Ruby GC heap growth to avoid allocating memory we won't use.
ENV RUBY_GC_HEAP_GROWTH_FACTOR=1.1

# Disable sourcemaps — saves ~2 GB RAM during Vite build
ENV GENERATE_SOURCEMAP=false
ENV NODE_ENV=production

# Tell build.rake to skip its redundant `pnpm install`
ENV SKIP_PNPM_INSTALL_IN_RAKE=1

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

# ── Git commit SHA ────────────────────────────────────────────────────────────
# .git is excluded from the build context (.dockerignore) to save ~514 MB.
# Render provides RENDER_GIT_COMMIT automatically; fall back to GIT_SHA arg.
ARG RENDER_GIT_COMMIT=""
ARG GIT_SHA=""

# ── Runtime-only system packages ─────────────────────────────────────────────
# No compilers needed — gems are pre-built in Stage 1, and npm packages
# for this project don't require node-gyp / native compilation.
RUN apk update && apk add --no-cache \
  openssl \
  libstdc++ \
  tar \
  tzdata \
  postgresql-client \
  curl \
  xz \
  vips \
  && gem install bundler -v "$BUNDLER_VERSION"

# ── Node + pnpm ──
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION}

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

WORKDIR /app

# ── Pre-built gems from Stage 1 (no compilation, fast COPY) ──
COPY --from=gem-builder /gems/ /gems/

# ── Node dependencies ──
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile \
  && pnpm store prune

# ── Application source ──
# Build context is ~100 MB thanks to comprehensive .dockerignore
# (.git, node_modules, vendor/bundle, spec, etc. are all excluded)
COPY . /app

RUN mkdir -p /app/log

# Write git SHA from Render env var or CI build arg
RUN echo "${RENDER_GIT_COMMIT:-${GIT_SHA:-unknown}}" > /app/.git_sha

# ── Asset precompilation ──
# Runs: SDK library build (Vite) → main app build (Vite) → Sprockets
# Peak memory: Ruby (~800 MB) + Vite (~768 MB cap) ≈ 1.6 GB
RUN SECRET_KEY_BASE=precompile_placeholder \
  RAILS_LOG_TO_STDOUT=enabled \
  GENERATE_SOURCEMAP=false \
  bundle exec rake assets:precompile

# ── Post-compile cleanup: strip everything Node-related ──
RUN rm -rf \
  node_modules \
  .pnpm-store \
  tmp/cache \
  /root/.local/share/pnpm \
  /root/.npm \
  /root/.cache

# =============================================================================
# Stage 3: Final runtime image — lean, no build tooling
# =============================================================================
FROM ruby:3.4.4-alpine3.21

ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16

ARG EXECJS_RUNTIME="Disabled"
ENV EXECJS_RUNTIME=${EXECJS_RUNTIME}

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

ARG BUNDLE_FORCE_RUBY_PLATFORM=1
ENV BUNDLE_FORCE_RUBY_PLATFORM=${BUNDLE_FORCE_RUBY_PLATFORM}

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"

RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tzdata \
  postgresql-client \
  imagemagick \
  git \
  vips \
  && gem install bundler -v "$BUNDLER_VERSION"

COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN if [ "$RAILS_ENV" != "production" ]; then \
  apk add --no-cache curl \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION} \
  && pnpm --version; \
  fi

COPY --from=asset-builder /gems/ /gems/
COPY --from=asset-builder /app /app
COPY --from=asset-builder /app/.git_sha /app/.git_sha

WORKDIR /app

EXPOSE 3000
