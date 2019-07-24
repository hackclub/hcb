FROM ruby:2.5.5

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# From https://superuser.com/a/1423685 - fixes broken Debian sources
RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list

# Install latest version of pg_restore for easy importing of production
# database & vim for easy editing of credentials.
RUN apt-get -y update && apt-get -y install postgresql-client
ENV EDITOR=vim

ADD Gemfile /usr/src/app/Gemfile
ADD Gemfile.lock /usr/src/app/Gemfile.lock

ENV BUNDLE_GEMFILE=Gemfile \
  BUNDLE_JOBS=4 \
  BUNDLE_PATH=/bundle

RUN bundle install

ADD . /usr/src/app
