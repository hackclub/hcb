# frozen_string_literal: true


class OauthApplication < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

  has_many :resource_grants, as: :owner, dependent: :destroy

  SPECIAL_SCOPES = {
    "restricted"  => { label: "Restricted", description: "Enforce the per-action scopes below. Without this, the token falls back to legacy full access and every other scope here is ignored.", group: "General" },
    "admin:read"  => { label: "Admin read", description: "Read-only access to admin-level data across all resources.", group: "Admin" },
    "admin:write" => { label: "Admin write", description: "Write access to admin-only actions across all resources.", group: "Admin" },
  }.freeze

  SCOPE_DESCRIPTIONS = {
    "organizations:read" => "View organizations, sub-organizations, and balances.",
    "ledgers:read"       => "View an organization's transaction ledger.",
    "receipts:read"      => "View uploaded receipts.",
    "receipts:write"     => "Upload or delete receipts.",
    "transfers:write"    => "Create disbursements, ACH transfers, and checks.",
    "card_grants:write"  => "Issue card grants.",
    "users:read"         => "View user profiles.",
    "user_lookup"        => "Look up a user by email.",
    "event_followers"    => "Manage an organization's followers.",
  }.freeze

  # Every scope enforced by a `require_oauth2_scope` declaration in Api::V4
  # controllers.
  def self.declared_scopes
    Dir[Rails.root.join("app/controllers/api/v4/**/*.rb")].each do |file|
      Pathname.new(file)
              .relative_path_from(Rails.root.join("app/controllers"))
              .to_s
              .delete_suffix(".rb")
              .camelize
              .safe_constantize
    end

    Api::V4::ApplicationController.descendants.flat_map do |controller|
      (controller.instance_variable_get(:@oauth_requirements) || {}).values.flatten
    end.uniq.sort
  end

  def self.declared_resource_types
    declared_scopes.filter_map { |value| value.split(":", 2).first if value.include?(":") }.uniq.sort
  end

  def self.scope_groups
    scopes_by_group = Hash.new { |hash, key| hash[key] = [] }

    SPECIAL_SCOPES.each do |value, meta|
      scopes_by_group[meta[:group]] << { value:, label: meta[:label], description: meta[:description] }
    end

    declared_scopes.each do |value|
      next if SPECIAL_SCOPES.key?(value)

      resource, action = value.split(":", 2)
      group = action ? resource.tr("_", " ").titleize : "Other capabilities"
      label = action ? "#{action.titleize} #{resource.tr('_', ' ')}" : value.tr("_", " ").titleize
      description = SCOPE_DESCRIPTIONS[value] || "Grants \"#{value}\" access."

      scopes_by_group[group] << { value:, label:, description: }
    end

    declared_resource_types.each do |resource|
      readable = resource.tr("_", " ")
      scopes_by_group["Admin"] << { value: "admin.#{resource}:read", label: "Admin read #{readable}", description: "Read-only access to admin-level data, limited to #{readable}." }
      scopes_by_group["Admin"] << { value: "admin.#{resource}:write", label: "Admin write #{readable}", description: "Write access to admin-only actions, limited to #{readable}." }
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
