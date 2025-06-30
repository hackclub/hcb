# frozen_string_literal: true

RailsPgExtras.configure do |config|
  # Disable the built-in password authentication as we are already using
  # `AdminConstraint` to limit access
  # https://github.com/pawurb/rails-pg-extras/blob/ac0169e358a439b1058d0b226fafb8c57e975e25/README.md#visual-interface
  config.public_dashboard = true

  # Disable potentially dangerous actions
  # https://github.com/pawurb/rails-pg-extras/blob/ac0169e358a439b1058d0b226fafb8c57e975e25/lib/rails_pg_extras/web.rb#L5
  config.enabled_web_actions = %i[pg_stat_statements_reset]
end
