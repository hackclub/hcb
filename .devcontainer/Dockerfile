FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install Ruby
ARG RUBY_VERSION="3.4"
RUN su vscode -c "gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"
RUN su vscode -c "curl -sSL https://get.rvm.io | bash -s stable"
RUN su vscode -c "/bin/bash -l -c \"rvm install ${RUBY_VERSION}\""
RUN su vscode -c "/bin/bash -l -c \"rvm --default use ${RUBY_VERSION}\""

# Install Rails
RUN su vscode -c "/bin/bash -l -c \"gem install rails webdrivers\""
RUN su vscode -c "/bin/bash -l -c \"rvm fix-permissions\""

ARG NODE_VERSION="22"
RUN su vscode -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
RUN su vscode -c "\
  export NVM_DIR=/home/vscode/.nvm && \
  source \$NVM_DIR/nvm.sh && \
  nvm install ${NODE_VERSION} && \
  nvm alias default ${NODE_VERSION} && \
  corepack enable \
"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains 
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
		# These libraries are used by rails or helpful for development
    postgresql-client \
    libpq-dev \
    poppler-utils \
    gir1.2-freedesktop \
    gir1.2-glib-2.0 \
    libgirepository-1.0-1 \
    libgirepository1.0-dev \
    libpoppler-glib-dev \
    libcairo-gobject2 \
    yarn \
    imagemagick
