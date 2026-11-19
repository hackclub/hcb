FROM mcr.microsoft.com/devcontainers/base:bookworm

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    libssl-dev \
    libreadline-dev \
    libyaml-dev \
    zlib1g-dev \
    postgresql-client \
    libpq-dev \
    poppler-utils \
    gir1.2-freedesktop \
    gir1.2-glib-2.0 \
    libgirepository-1.0-1 \
    libgirepository1.0-dev \
    libpoppler-glib-dev \
    libcairo-gobject2 \
    imagemagick

# Use shims for non-login shells and restore them when login profiles reset PATH.
ENV MISE_DATA_DIR=/home/vscode/.local/share/mise \
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=ruby,node \
    PATH="/home/vscode/.local/share/mise/shims:${PATH}" \
    BUNDLE_PATH=/usr/local/bundle
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && printf '%s\n' 'export PATH="/home/vscode/.local/share/mise/shims:$PATH"' > /etc/profile.d/mise.sh \
    && install -d -o vscode -g vscode /usr/local/bundle

USER vscode
WORKDIR /home/vscode
COPY --chown=vscode:vscode .ruby-version .node-version ./
RUN mise install && corepack enable && mise reshim
