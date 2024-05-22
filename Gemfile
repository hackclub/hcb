# frozen_string_literal: true

source "https://rubygems.org"

ruby File.read(File.join(File.dirname(__FILE__), ".ruby-version")).strip

gem "dotenv-rails", groups: [:development, :test]

gem "rails", "~> 7.1.3"

gem "puma", "~> 6.4" # app server

gem "pg", ">= 0.18", "< 2.0" # database
gem "redis", "~> 5.0" # for caching, jobs, etc.
gem "sidekiq", "~> 7.1.3" # background jobs
gem "sidekiq-cron", "~> 1.10" # run Sidekiq jobs at scheduled intervals

gem "image_processing", "~> 1.2"
gem "mini_magick"


gem "jsbundling-rails", "~> 1.1"
gem "terser", "~> 1.1" # JS compressor
gem "jquery-rails"
gem "react-rails"
gem "turbo-rails", "~> 1.4"

gem "invisible_captcha"
gem "local_time" # client-side timestamp converter for cache-safe rendering
gem "countries"
gem "country_select", "~> 8.0"

gem "faraday" # web requests

gem "increase", "~> 0.3.1"
gem "stripe", "8.5.0"
gem "plaid", "~> 26.0"
gem "yellow_pages", github: "hackclub/yellow_pages", ref: "117d13e"

gem "aws-sdk-s3", require: false

gem "airrecord", "~> 1.0" # Airtable API for internal operations

gem "twilio-ruby" # SMS notifications

gem "lob"

gem "google-apis-admin_directory_v1", "~> 0.45.0" # GSuite

gem "pg_search" # full-text search

gem "lockbox" # encrypt sensitive data
gem "blind_index" # needed to query and/or guarantee uniqueness for encrypted fields with lockbox

gem "aasm" # state machine

gem "paper_trail", "~> 15.1.0" # track changes to models
gem "acts_as_paranoid", "~> 0.9.0" # enables soft deletions

gem "friendly_id", "~> 5.5.0" # slugs
gem "hashid-rails", "~> 1.0" # obfuscate IDs in URLs

gem "active_storage_validations", "1.1.4" # file validations
gem "validates_email_format_of" # email address validations
gem "phonelib" # phone number validations

gem "money-rails"
gem "monetize"
gem "rounding"

gem "business_time"


gem "poppler" # PDF parsing
gem "wicked_pdf" # HTML to PDF conversion


gem "rack-cors" # manage CORS
gem "rack-attack" # rate limiting
gem "browser", "~> 5.3" # browser detection

# Pagination
gem "kaminari"
gem "api-pagination"


gem "flipper" # feature flags
gem "flipper-active_record"
gem "flipper-ui"

gem "scientist" # helps refactor code for critical paths with confidence
# gem "lab_tech" # collects data from scientist experiments
gem "table_print" # pretty prints tables in console (used with lab_tech)


gem "pundit" # implements authorization policies

# API V3
gem "grape"
gem "grape-entity" # For Grape::Entity ( https://github.com/ruby-grape/grape-entity )
gem "grape-kaminari"
gem "grape-route-helpers"
gem "grape-swagger"
gem "grape-swagger-entity", "~> 0.3"

gem "maildown" # markdown for views
gem "redcarpet" # markdown parsing
gem "loofah" # html email parsing

gem "namae" # multi-cultural human name parser
gem "premailer-rails" # css to inline styles for emails
gem "safely_block"
gem "strong_migrations" # protects against risky migrations
gem "swagger-blocks"
gem "xxhash" # fast hashing

gem "diffy" # rendering diffs (comments)

gem "webauthn", "~> 3.0"

gem "ahoy_matey" # analytics
gem "airbrake" # exception tracking
gem "blazer" # business intelligence tool/dashboard

gem "geo_pattern" # create procedurally generated patterns for Cards
gem "comma", "~> 4.7" # CSV generation
gem "faker" # Create mock data

gem "chronic" # time/date parsing
gem "rinku", require: "rails_rinku" # auto-linking URLs in text

gem "geocoder" # lookup lat/lng for Stripe Cards shipment tracking
gem "validates_zipcode" # validation for event's zip codes

gem "rqrcode" # QR code generation

gem "brakeman" # static security vulnerability scanner

gem "awesome_print" # pretty print objects in console
gem "byebug", platforms: [:windows]
gem "dry-validation"

gem "bootsnap", ">= 1.4.4", require: false # reduces boot times through caching; required in config/boot.rb

gem "appsignal" # error tracking + performance monitoring
gem "lograge" # Log formatting
gem "statsd-instrument", "~> 3.5", ">= 3.5.12" # For reporting to HC Grafana

group :production do

  # gem "heroku-deflater" # compression

  # Heroku language runtime metrics
  # https://devcenter.heroku.com/articles/language-runtime-metrics-ruby#add-the-barnes-gem-to-your-application
  gem "barnes"
end

group :test do
  gem "factory_bot_rails" # Test data
  gem "simplecov", require: false # Code coverage
end

group :development, :test do
  gem "erb_lint", require: false
  gem "rubocop"
  gem "rubocop-rails", "~> 2.22"
  gem "relaxed-rubocop"

  gem "rspec-rails", "~> 6.1.2"

  # Lets you set a breakpoint with a REPL using binding.pry
  gem "pry-byebug", require: ENV["EXCLUDE_PRY"] != "true"
  gem "pry-rails", require: ENV["EXCLUDE_PRY"] != "true"
end

group :development, :staging do
  gem "query_count"

  gem "rack-mini-profiler", "~> 3.1"
  gem "stackprof" # used by `rack-mini-profiler` to provide flamegraphs
end

group :development do
  gem "annotate" # comment models with database schema

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "listen", "~> 3.8"
  gem "web-console", ">= 3.3.0"

  gem "letter_opener_web" # preview emails

  gem "wkhtmltopdf-binary", "0.12.6.6" # version must match the wkhtmltopdf Heroku buildpack version (0.12.3 by default)

  # Ruby language server
  gem "solargraph", require: false
  gem "solargraph-rails", "~> 0.2.0", require: false

  gem "htmlbeautifier", require: false # for https://marketplace.visualstudio.com/items?itemName=tomclose.format-erb

  gem "foreman"

  gem "bullet"
end

gem "jbuilder", "~> 2.11"

gem "ledgerjournal"
gem "doorkeeper", "~> 5.6"

gem "cssbundling-rails", "~> 1.4"

gem "sprockets-rails", "~> 3.4"
