# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.3.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /app

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      # Active Storage
      imagemagick \
      libvips \
      poppler-utils \
      # Better memory management
      libjemalloc2 \
      # Postgres
      postgresql \
      # Poppler gem (https://github.com/ruby-gnome/ruby-gnome/tree/main/poppler)
      gir1.2-freedesktop \
      gir1.2-glib-2.0 \
      libcairo-gobject2 \
      libgirepository-1.0-1 \
      libpoppler-glib-dev \
      # OCR
      tesseract-ocr \
      # PDF generation
      wkhtmltopdf && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    RACK_ENV="production" \
    NODE_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config \
      # Building node
      node-gyp \
      python-is-python3 \
      # Postgres
      libpq-dev \
      # Poppler gem
      libcairo2-dev \
      libgirepository1.0-dev \
      libglib2.0-dev \
    && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG NODE_VERSION=22.10.0
ARG YARN_VERSION=1.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install application gems
COPY Gemfile Gemfile.lock vendor .ruby-version ./

RUN gem install bundler -v 2.5.17

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Remove non-prod master key
RUN rm -f config/master.key

# Precompile assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

RUN rm -rf node_modules

# Final stage for app image
FROM base

# Add build timestamp
RUN date +%s > .build-timestamp

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /app /app

# Entrypoint prepares the database.
ENTRYPOINT ["./bin/docker-entrypoint"]

# Start the server
EXPOSE 3000
CMD ["./bin/rails", "server"]
