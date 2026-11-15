# frozen_string_literal: true

# Mark existing migrations as safe
StrongMigrations.start_after = 20200812000005

# Set timeouts for migrations
# If you use PgBouncer in transaction mode, delete these lines and set timeouts on the database user
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Outdated statistics can sometimes hurt performance
StrongMigrations.auto_analyze = true

# This can be removed once upgraded to Rails 8.1
StrongMigrations.alphabetize_schema = true

# Set the version of the production database
# so the right checks are run in development
# StrongMigrations.target_version = 10

# Add custom checks
# StrongMigrations.add_check do |method, args|
#   if method == :add_index && args[0].to_s == "users"
#     stop! "No more indexes on the users table"
#   end
# end
