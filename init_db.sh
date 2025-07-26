#!/usr/bin/env bash

# Setup PostgreSQL

bundle exec rails db:prepare
bundle exec rails db:test:prepare
bundle exec rails db:migrate