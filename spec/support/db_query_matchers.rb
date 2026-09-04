# frozen_string_literal: true

require "db-query-matchers"

DBQueryMatchers.configure do |config|
  # Schema-introspection queries aren't part of the behavior a query-count
  # assertion cares about; excluding them matches Rails' own
  # assert_queries_count default.
  config.schemaless = true
end
