# frozen_string_literal: true

# Extends Doorkeeper's own Application model with:
#   - the resource grants copied onto every token minted for it (see
#     after_successful_strategy_response in doorkeeper.rb)
#   - the human-readable scope catalog that drives the checkbox picker on the
#     OAuth application form (app/views/doorkeeper/applications/_form.html.erb),
#     so scopes don't have to be typed in by hand
#
# Kept in its own initializer, separate from Doorkeeper.configure, since it's
# plain model behavior rather than provider configuration.
#
# The scope inventory itself is pulled programmatically from every
# `require_oauth2_scope` declaration in Api::V4 controllers (plus the
# blanket/sentinel scopes, which aren't declared that way) - so it never
# drifts out of sync with what the API actually enforces. Only the
# human-readable copy (label/description/grouping) is hand-maintained, and
# falls back to a generated default for any scope without curated copy.

# Defined at the top level (not inside to_prepare below) since this data
# never changes across reloads - only the Doorkeeper::Application class_eval
# needs to rerun when Zeitwerk reloads that constant in development.
module DoorkeeperApplicationScopeCatalogData
  SPECIAL_SCOPES = {
    "restricted" => { label: "Restricted", description: "Enforce the per-action scopes below. Without this, the token falls back to legacy full access and every other scope here is ignored.", group: "General" },
    "admin:read" => { label: "Admin read", description: "Read-only access to admin-level data across all resources.", group: "Admin" },
    "admin:write" => { label: "Admin write", description: "Write access to admin-only actions across all resources.", group: "Admin" },
  }.freeze

  SCOPE_DESCRIPTIONS = {
    "organizations:read" => "View organizations, sub-organizations, and balances.",
    "ledgers:read" => "View an organization's transaction ledger.",
    "receipts:read" => "View uploaded receipts.",
    "receipts:write" => "Upload or delete receipts.",
    "transfers:write" => "Create disbursements, ACH transfers, and checks.",
    "card_grants:write" => "Issue card grants.",
    "users:read" => "View user profiles.",
    "user_lookup" => "Look up a user by email.",
    "event_followers" => "Manage an organization's followers.",
  }.freeze

  V4_CONTROLLERS_DIR = Rails.root.join("app/controllers/api/v4")
end

Rails.application.config.to_prepare do
  Doorkeeper::Application.class_eval do
    has_many :resource_grants, as: :owner, dependent: :destroy

    # Loads every Api::V4 controller class so `require_oauth2_scope`
    # declarations (evaluated at class-body time) have actually run. Zeitwerk
    # only autoloads a constant when it's referenced, so without this,
    # controllers nobody has hit yet in this process would be invisible here.
    def self.declared_scopes
      Dir[DoorkeeperApplicationScopeCatalogData::V4_CONTROLLERS_DIR.join("**/*.rb")].each do |file|
        file
          .delete_prefix("#{Rails.root}/app/controllers/")
          .delete_suffix(".rb")
          .camelize
          .safe_constantize
      end

      Api::V4::ApplicationController.descendants.flat_map do |controller|
        (controller.instance_variable_get(:@oauth_requirements) || {}).values.flatten
      end.uniq.sort
    end

    def self.scope_groups
      special_scopes = DoorkeeperApplicationScopeCatalogData::SPECIAL_SCOPES
      descriptions = DoorkeeperApplicationScopeCatalogData::SCOPE_DESCRIPTIONS
      scopes_by_group = Hash.new { |hash, key| hash[key] = [] }

      special_scopes.each do |value, meta|
        scopes_by_group[meta[:group]] << { value:, label: meta[:label], description: meta[:description] }
      end

      declared_scopes.each do |value|
        next if special_scopes.key?(value)

        resource, action = value.split(":", 2)
        group = action ? resource.tr("_", " ").titleize : "Other capabilities"
        label = action ? "#{action.titleize} #{resource.tr('_', ' ')}" : value.tr("_", " ").titleize
        description = descriptions[value] || "Grants \"#{value}\" access."

        scopes_by_group[group] << { value:, label:, description: }
      end

      scopes_by_group
        .map { |name, scopes| { name:, scopes: scopes.sort_by { |scope| scope[:value] } } }
        .sort_by { |group| [{ "General" => 0, "Admin" => 2 }.fetch(group[:name], 1), group[:name]] }
    end

    def self.scope_catalog_values
      scope_groups.flat_map { |group| group[:scopes].map { |scope| scope[:value] } }
    end

    def self.split_scopes(scopes_string)
      requested = scopes_string.to_s.split
      values = scope_catalog_values
      [requested & values, requested - values]
    end
  end
end
