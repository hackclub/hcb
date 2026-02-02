# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "dotenv-rails", groups: [:development, :test]

gem "rails", "~> 8.0"

gem "puma", "~> 6.6" # app server

gem "pg", ">= 0.18", "< 2.0" # database
gem "fx"
gem "redis", "~> 5.4" # for caching, jobs, etc.
gem "sidekiq", "~> 7.3.8" # background jobs
gem "sidekiq-cron", "~> 2.3" # run Sidekiq jobs at scheduled intervals
gem "activejob-traffic_control" # throttle jobs
gem "suo", github: "instacart/suo" # suo is a transitive dependency of activejob-traffic_control
# explicitly use instacart fork here to work around dalli log in upstream https://github.com/nickelser/suo/pull/21

gem "image_processing", "~> 1.2"
gem "mini_magick"


gem "jsbundling-rails", "~> 1.3"
gem "terser", "~> 1.2" # JS compressor
gem "jquery-rails"
gem "react-rails"
gem "turbo-rails", "~> 2.0.17"

gem "invisible_captcha"
gem "local_time" # client-side timestamp converter for cache-safe rendering
gem "countries"
gem "country_select", "~> 8.0"

gem "faraday" # web requests

gem "stripe", "11.7.0"
gem "plaid", "~> 44.0"
gem "yellow_pages", github: "hackclub/yellow_pages"

gem "aws-sdk-s3", require: false

gem "airrecord", "~> 1.0" # Airtable API for internal operations

gem "twilio-ruby" # SMS notifications

gem "google-apis-admin_directory_v1", "~> 0.67.0" # GSuite

gem "pg_search" # full-text search

gem "lockbox" # encrypt sensitive data
gem "blind_index" # needed to query and/or guarantee uniqueness for encrypted fields with lockbox

gem "aasm" # state machine

gem "paper_trail", "~> 16.0.0" # track changes to models
gem "acts_as_paranoid", "~> 0.10.3" # enables soft deletions

gem "friendly_id", "~> 5.6.0" # slugs
gem "hashid-rails", "~> 1.0" # obfuscate IDs in URLs

gem "active_storage_validations", "3.0.1" # file validations
gem "validates_email_format_of" # email address validations
gem "phonelib" # phone number validations

gem "money-rails"
gem "monetize"
gem "rounding"

gem "business_time"


gem "poppler" # PDF parsing
gem "wicked_pdf" # HTML to PDF conversion

gem "write_xlsx" # Export Excel files
gem "rubyzip", "< 3.0", ">= 2.3.0" # Force `write_xlsx` to use an older version of `rubyzip`. See https://github.com/cxn03651/write_xlsx/issues/127

gem "rack-cors" # manage CORS
gem "rack-attack" # rate limiting
gem "browser", "~> 6.2" # browser detection

# Pagination
gem "kaminari"
gem "api-pagination"


gem "flipper" # feature flags
gem "flipper-active_record"
gem "flipper-ui"

gem "pundit" # implements authorization policies

# API V3
gem "grape"
gem "grape-entity" # For Grape::Entity ( https://github.com/ruby-grape/grape-entity )
gem "grape-kaminari"
gem "grape-route-helpers"
gem "grape-swagger"
gem "grape-swagger-entity", "~> 0.7"

gem "redcarpet" # markdown parsing
gem "loofah" # html email parsing
gem "reverse_markdown" # public activity to discord

gem "namae" # multi-cultural human name parser
gem "premailer-rails" # css to inline styles for emails
gem "safely_block"
gem "strong_migrations", "~> 2" # protects against risky migrations
gem "xxhash" # fast hashing
gem "memo_wise"

gem "diffy" # rendering diffs (comments)

gem "webauthn", "~> 3.4"

gem "ahoy_matey" # analytics
gem "blazer" # business intelligence tool/dashboard

gem "geo_pattern" # create procedurally generated patterns for Cards
gem "comma", "~> 4.8" # CSV generation
gem "faker" # Create mock data

gem "chronic" # time/date parsing
gem "rinku", require: "rails_rinku" # auto-linking URLs in text

gem "geocoder" # lookup lat/lng for Stripe Cards shipment tracking
gem "validates_zipcode" # validation for event's zip codes

gem "rqrcode" # QR code generation

gem "awesome_print" # pretty print objects in console
gem "byebug", platforms: [:windows]

gem "bootsnap", ">= 1.4.4", require: false # reduces boot times through caching; required in config/boot.rb

gem "appsignal" # error tracking + performance monitoring
gem "lograge" # Log formatting
gem "statsd-instrument", "~> 3.9" # For reporting to HC Grafana

group :test do
  gem "factory_bot_rails" # Test data
  gem "simplecov", require: false # Code coverage
  gem "webmock"
end

group :development, :test do
  gem "erb_lint", require: false
  gem "rubocop"
  gem "rubocop-rails", "~> 2.30"
  gem "relaxed-rubocop"
  gem "brakeman" # static security vulnerability scanner

  gem "rspec-rails", "~> 7.1.1"

  # Lets you set a breakpoint with a REPL using binding.pry
  gem "pry-byebug", require: ENV["EXCLUDE_PRY"] != "true"
  gem "pry-rails", require: ENV["EXCLUDE_PRY"] != "true"
end

gem "query_count"

gem "rack-mini-profiler", "~> 3.3"
gem "stackprof" # used by `rack-mini-profiler` to provide flamegraphs

gem "wkhtmltopdf-binary", "0.12.6.8"

group :development do
  gem "annotaterb" # comment models with database schema
  gem "actual_db_schema" # rolls back phantom migrations

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "listen", "~> 3.9"
  gem "web-console", ">= 3.3.0"

  gem "letter_opener_web" # preview emails

  # Ruby language server
  gem "solargraph", require: false
  gem "solargraph-rails", "~> 1.2.0", require: false

  gem "htmlbeautifier", require: false # for https://marketplace.visualstudio.com/items?itemName=tomclose.format-erb

  gem "foreman"

  gem "bullet"
end

gem "jbuilder", "~> 2.13"

gem "ledgerjournal"
gem "doorkeeper", "~> 5.8"
gem "doorkeeper-device_authorization_grant"

gem "cssbundling-rails", "~> 1.4"

gem "rtesseract"

gem "sprockets-rails", "~> 3.5"

gem "public_activity", ">= 3.0.2"

gem "console1984"
gem "audits1984"

gem "rotp"

gem "ruby-limiter"

gem "ahoy_email", "~> 2.4"

gem "email_reply_parser"

gem "eu_central_bank"

gem "whitesimilarity"

gem "rack-timeout", require: "rack/timeout/base"

gem "irb"

gem "pstore"

gem "bcrypt", "~> 3.1.7"

gem "prosemirror_to_html"

gem "ed25519"
gem "discordrb"

gem "pghero", "~> 3.7"
gem "pg_query", ">= 2"

gem "intercom-rails"
