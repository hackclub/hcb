# frozen_string_literal: true

# ActualDbSchema initializer
#
# I decided to skip the git hook installation because automatic rollbacks can
# cause unexpected data loss. It's not a huge issue since this is in
# development, but can be annoying.
# ~ @garyhtou

ActualDbSchema.configure do |config|
  # Enable the gem.
  config.enabled = Rails.env.development?

  # Disable automatic rollback of phantom migrations.
  # config.auto_rollback_disabled = true
  config.auto_rollback_disabled = ENV["ACTUAL_DB_SCHEMA_AUTO_ROLLBACK_DISABLED"].present?

  # Enable the UI for managing migrations.
  config.ui_enabled = Rails.env.development? || ENV["ACTUAL_DB_SCHEMA_UI_ENABLED"].present?

  # Enable automatic phantom migration rollback on branch switch,
  # config.git_hooks_enabled = true
  config.git_hooks_enabled = ENV["ACTUAL_DB_SCHEMA_GIT_HOOKS_ENABLED"].present?

  # If your application leverages multiple schemas for multi-tenancy, define the active schemas.
  # config.multi_tenant_schemas = -> { ["public", "tenant1", "tenant2"] }

  # Enable console migrations.
  # config.console_migrations_enabled = true
  config.console_migrations_enabled = ENV["ACTUAL_DB_SCHEMA_CONSOLE_MIGRATIONS_ENABLED"].present?

  # Define the migrated folder location.
  # config.migrated_folder = Rails.root.join("custom", "migrated")
  config.migrated_folder = Rails.root.join("tmp", "migrated")
end
