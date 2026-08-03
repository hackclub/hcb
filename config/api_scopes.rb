# frozen_string_literal: true

# Single source of truth for the OAuth scopes the v4 API supports.
#
# This lives in `config/` rather than `app/` or `lib/` because the Doorkeeper initializer needs it
# at boot, before autoloading is available.
module ApiScopes

  # Tokens carrying this scope are held to the granular scopes below: every action they touch must
  # declare one via `require_oauth2_scope`, and the token must carry it (see
  # `Api::V4::ApplicationController#check_restricted_scopes!`).
  #
  # Tokens *without* it keep the historical behaviour — full access to everything the user can
  # reach — so existing integrations aren't broken by this list growing.
  RESTRICTED = "restricted"

  # The original coarse scopes. `read` and `write` predate the granular list and are what the
  # mobile app requests; `admin:*` additionally require the user to actually hold the role, which
  # `Api::V4::AdminScopeCheckable` enforces separately.
  BROAD = {
    "read"        => "Read your HCB data",
    "write"       => "Make changes to your HCB data",
    "admin:read"  => "Read data across all of HCB (admins only)",
    "admin:write" => "Make changes across all of HCB (admins only)"
  }.freeze

  # Granular scopes, only meaningful on a `restricted` token. Every entry here must correspond to a
  # `require_oauth2_scope` declaration in a controller — the spec in
  # `spec/controllers/api/v4/oauth_scopes_spec.rb` fails if the two drift apart.
  GRANULAR = {
    "organizations:read" => "See the organizations you're part of",
    "ledgers:read"       => "See your transactions and their details",
    "transactions:write" => "Rename transactions and change their tags",
    "receipts:read"      => "See your receipts",
    "receipts:write"     => "Upload receipts and mark transactions as missing one",
    "comments:read"      => "Read comments on transactions",
    "comments:write"     => "Post comments on transactions",
    "tags:read"          => "See your organizations' tags",
    "tags:write"         => "Create and delete tags",
    "transfers:write"    => "Send money between your organizations",
    "card_grants:write"  => "Issue card grants",
    "users:read"         => "See your name, email, and profile",
    "user_lookup"        => "Look up other HCB users by email",
    "event_followers"    => "See who follows an organization"
  }.freeze

  DESCRIPTIONS = BROAD.merge(GRANULAR).merge(
    RESTRICTED => "Limit this app to only the permissions listed here"
  ).freeze

  # Everything an application is allowed to request.
  ALL = DESCRIPTIONS.keys.freeze

  # @return [Array<Symbol>] every configurable scope, for Doorkeeper's `optional_scopes`.
  def self.optional
    ALL.map(&:to_sym)
  end

  # @param scope [String]
  # @return [String] a human-readable description, falling back to the raw scope name.
  def self.describe(scope)
    DESCRIPTIONS.fetch(scope.to_s, scope.to_s)
  end

  # @param scopes [Enumerable<String>]
  # @return [Boolean] whether these scopes opt into granular enforcement.
  def self.restricted?(scopes)
    scopes.to_a.map(&:to_s).include?(RESTRICTED)
  end

  # The scopes to actually show a user on a consent screen — `restricted` itself is plumbing, not a
  # permission, so listing it alongside real permissions would just be noise.
  #
  # @param scopes [Enumerable<String>]
  # @return [Array<String>]
  def self.presentable(scopes)
    scopes.to_a.map(&:to_s).reject { |scope| scope == RESTRICTED }
  end

end
