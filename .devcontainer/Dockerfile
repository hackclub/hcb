FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install Ruby and Node from .ruby-version and .node-version
ENV MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=ruby,node \
    PATH="/home/vscode/.local/share/mise/shims:${PATH}"
COPY .ruby-version .node-version /home/vscode/
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && echo 'export PATH="/home/vscode/.local/share/mise/shims:$PATH"' > /etc/profile.d/mise.sh
RUN su vscode -c "cd /home/vscode && mise install && corepack enable && mise reshim"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    postgresql-client \
    libpq-dev \
    poppler-utils \
    gir1.2-freedesktop \
    gir1.2-glib-2.0 \
    libgirepository-1.0-1 \
    libgirepository1.0-dev \
    libpoppler-glib-dev \
    libcairo-gobject2 \
    imagemagick \
    # Draws CSV previews (csv_preview gem)
    libvips

# Install the RWX CLI (https://www.rwx.com/docs/cli-reference)
RUN tmp="$(mktemp -d)" \
    && curl -o "$tmp/rwx" -fsSL "https://github.com/rwx-cloud/rwx/releases/download/latest/rwx-linux-$(uname -m)" \
    && install "$tmp/rwx" /usr/local/bin \
    && rm -rf "$tmp"
