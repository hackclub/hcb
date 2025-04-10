ARG VARIANT="3.4-bookworm"
FROM mcr.microsoft.com/devcontainers/ruby:${VARIANT}
# Install Rails
RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

ARG NODE_VERSION="22"
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
		# These libraries are used by rails or helpful for development
    postgresql-client \
    poppler-utils \
    gir1.2-freedesktop \
    gir1.2-glib-2.0 \
    libgirepository-1.0-1 \
    libgirepository1.0-dev \
    libpoppler-glib-dev \
    libcairo-gobject2 \
    yarn
