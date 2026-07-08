# frozen_string_literal: true

module DoorkeeperScopeCatalog
  SPECIAL_SCOPES = {
    "restricted" => { label: "Restricted", description: "Enforce the per-action scopes below. Without this, the token falls back to legacy full access and every other scope here is ignored.", group: "General" },
    "admin:read" => { label: "Admin read", description: "Read-only access to admin-level data across all resources.", group: "Admin" },
    "admin:write" => { label: "Admin write", description: "Write access to admin-only actions across all resources.", group: "Admin" },
  }.freeze

  DESCRIPTIONS = {
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

  CONTROLLERS_DIR = Rails.root.join("app/controllers/api/v4")

  def self.load_all_v4_controllers!
    Dir[CONTROLLERS_DIR.join("**/*.rb")].each do |file|
      file
        .delete_prefix("#{Rails.root}/app/controllers/")
        .delete_suffix(".rb")
        .camelize
        .safe_constantize
    end
  end

  def self.declared_scopes
    load_all_v4_controllers!

    Api::V4::ApplicationController.descendants.flat_map do |controller|
      (controller.instance_variable_get(:@oauth_requirements) || {}).values.flatten
    end.uniq.sort
  end

  def self.groups
    scopes_by_group = Hash.new { |hash, key| hash[key] = [] }

    SPECIAL_SCOPES.each do |value, meta|
      scopes_by_group[meta[:group]] << { value:, label: meta[:label], description: meta[:description] }
    end

    declared_scopes.each do |value|
      next if SPECIAL_SCOPES.key?(value)

      resource, action = value.split(":", 2)
      group = action ? resource.tr("_", " ").titleize : "Other capabilities"
      label = action ? "#{action.titleize} #{resource.tr('_', ' ')}" : value.tr("_", " ").titleize
      description = DESCRIPTIONS[value] || "Grants \"#{value}\" access."

      scopes_by_group[group] << { value:, label:, description: }
    end

    scopes_by_group
      .map { |name, scopes| { name:, scopes: scopes.sort_by { |scope| scope[:value] } } }
      .sort_by { |group| [{ "General" => 0, "Admin" => 2 }.fetch(group[:name], 1), group[:name]] }
  end

  def self.all_values
    groups.flat_map { |group| group[:scopes].map { |scope| scope[:value] } }
  end

  def self.split(scopes_string)
    requested = scopes_string.to_s.split
    values = all_values
    [requested & values, requested - values]
  end
end
