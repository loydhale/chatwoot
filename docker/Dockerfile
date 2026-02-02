# =============================================================================
# Stage 0: Node binary source
# =============================================================================
FROM node:24-alpine AS node

# =============================================================================
# Stage 1: Gem builder  —  compiles native extensions in isolation
# Peak memory: ~2 GB (grpc, nokogiri, etc.)
# Once this stage finishes, its peak memory is freed before assets compile.
# =============================================================================
FROM ruby:3.4.4-alpine3.21 AS gem-builder

ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.16
ENV BUNDLE_PATH="/gems"

RUN apk update && apk add --no-cache \
  build-base \
  musl \
  ruby-full \
  ruby-dev \
  gcc \
  make \
  musl-dev \
  openssl \
  openssl-dev \
  g++ \
  linux-headers \
  xz \
  vips \
  postgresql-dev \
  git \
  && gem install bundler -v "$BUNDLER_VERSION"

WORKDIR /app
COPY Gemfile Gemfile.lock ./

# Install only production gems — limit concurrency to reduce peak memory
RUN bundle config set without 'development test' \
  && bundle install -j 2 -r 3

# Strip gem cache + compiled C artifacts to slim the layer
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete

# =============================================================================
# Stage 2: Asset builder  —  node deps + vite/sprockets compilation
# Peak memory: ~3-4 GB  (was 5-6 GB before the split)
# Gems are pre-built; we just COPY them in, avoiding native-extension overhead.
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

# ── Node heap: capped at 1024 MB (down from 1536) ──
ARG NODE_OPTIONS="--max-old-space-size=1024 --openssl-legacy-provider"
ENV NODE_OPTIONS=${NODE_OPTIONS}

# Disable sourcemaps — saves ~2 GB RAM during Vite build
ENV GENERATE_SOURCEMAP=false
ENV NODE_ENV=production

# Tell build.rake to skip its redundant `pnpm install`
ENV SKIP_PNPM_INSTALL_IN_RAKE=1

ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}

# System deps (lighter set — no native gem compilation needed)
RUN apk update && apk add --no-cache \
  build-base \
  openssl \
  tar \
  tzdata \
  postgresql-dev \
  postgresql-client \
  git \
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
# Install with frozen lockfile; pnpm will skip devDeps it can when NODE_ENV=production,
# but vite/tailwind/postcss are needed so they're in the lockfile's resolution.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile \
  && pnpm store prune

# ── Application source ──
COPY . /app

RUN mkdir -p /app/log

# Capture commit SHA before .git is purged
RUN git rev-parse HEAD > /app/.git_sha

# ── Free disk/memory before the heavy compile step ──
RUN rm -rf \
  .git \
  spec \
  test \
  tmp/cache \
  .github \
  .devcontainer \
  .husky \
  coverage \
  stories

# ── Asset precompilation ──
# GENERATE_SOURCEMAP=false + --max-old-space-size=1024 keeps peak under 4 GB
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
# Stage 3: Final runtime image  —  lean, no build tooling
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
