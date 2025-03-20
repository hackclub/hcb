FROM ruby:3.3.7

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

RUN apt-get -y update -qq

# install postgresql-client for easy importing of production database & vim
# for easy editing of credentials
RUN apt-get -y install postgresql-client vim poppler-utils
ENV EDITOR=vim

# Install node22 & yarn

RUN curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh && \
  bash nodesource_setup.sh && \
  apt-get install -y nodejs

RUN corepack enable

RUN gem install bundler -v 2.5.17

ADD yarn.lock /usr/src/app/yarn.lock
ADD package.json /usr/src/app/package.json
ADD .ruby-version /usr/src/app/.ruby-version
ADD Gemfile /usr/src/app/Gemfile
ADD Gemfile.lock /usr/src/app/Gemfile.lock

ENV BUNDLE_GEMFILE=Gemfile \
  BUNDLE_JOBS=4 \
  BUNDLE_PATH=/usr/local/bundle

RUN bundle install
RUN yarn install --check-files

# Rubocop can't find config when ran with solargraph inside docker
# https://github.com/castwide/solargraph/issues/309#issuecomment-998137438
RUN ln -s /usr/src/app/.rubocop.yml ~/.rubocop.yml
RUN ln -s /usr/src/app/.rubocop_todo.yml ~/.rubocop_todo.yml

ADD . /usr/src/app

EXPOSE 3000

CMD ["bundle", "exec", "foreman", "start", "-f", "Procfile.dev", "-m", "all=1,stripe=0"]
