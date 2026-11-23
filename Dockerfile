# Local development image, built by docker-compose.yml (see docker_setup.sh and docker_start.sh).
# Use mise instead of the official Ruby image to simplify version management,
# but keep the same base image as the official Ruby image.
FROM buildpack-deps:trixie

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

RUN apt-get -y update -qq

# install postgresql-client for easy importing of production database & vim
# for easy editing of credentials. libvips draws CSV previews (csv_preview gem).
RUN apt-get -y install postgresql-client vim poppler-utils libvips
ENV EDITOR=vim

ENV MISE_DATA_DIR=/usr/local/share/mise \
  MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=ruby,node \
  PATH="/usr/local/share/mise/shims:${PATH}"
COPY .ruby-version .node-version ./
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
  && mise install && corepack enable && mise reshim

ADD yarn.lock /usr/src/app/yarn.lock
ADD package.json /usr/src/app/package.json
ADD Gemfile /usr/src/app/Gemfile
ADD Gemfile.lock /usr/src/app/Gemfile.lock

# Preserve the official Ruby image's shared gem directory, executable PATH,
# and Bundler config location outside the bind-mounted app directory.
# https://github.com/docker-library/ruby/blob/9c4fe994a013eba757c5b33eb7bf6132214ea611/4.0/trixie/Dockerfile#L105-L109
ENV BUNDLE_GEMFILE=Gemfile \
  BUNDLE_JOBS=4 \
  BUNDLE_PATH=/usr/local/bundle \
  BUNDLE_APP_CONFIG=/usr/local/bundle \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  GEM_HOME=/usr/local/bundle \
  PATH="/usr/local/bundle/bin:${PATH}"

RUN bundle install
RUN yarn install --check-files

# Rubocop can't find config when ran with solargraph inside docker
# https://github.com/castwide/solargraph/issues/309#issuecomment-998137438
RUN ln -s /usr/src/app/.rubocop.yml ~/.rubocop.yml
RUN ln -s /usr/src/app/.rubocop_todo.yml ~/.rubocop_todo.yml

ADD . /usr/src/app

# Preserve the official Ruby image's UTF-8 runtime locale.
# https://github.com/docker-library/ruby/blob/9c4fe994a013eba757c5b33eb7bf6132214ea611/4.0/trixie/Dockerfile#L14
ENV LANG=C.UTF-8

EXPOSE 3000

CMD ["bundle", "exec", "foreman", "start", "-f", "Procfile.dev", "-m", "all=1,stripe=0"]
