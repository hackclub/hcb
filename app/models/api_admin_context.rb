# frozen_string_literal: true

# Wraps a User for the Pundit policy context in the v4 API with respect to admin scopes and admin priviledges
class ApiAdminContext
  delegate_missing_to :@user
  attr_reader :token

  def initialize(user, token, default_resource: nil, default_record: nil)
    @user = user
    @token = token
    @default_resource = default_resource
    @default_record = default_record
  end

  # Returns a copy bound to the record (or class/relation) being authorized,
  # so bare admin?/auditor? calls default to its resource type. Non-resource
  # targets (symbols, arrays, ...) stay unbound: blanket scopes only.
  def for_record(target)
    case target
    when ActiveRecord::Relation
      for_record(target.klass)
    when Class
      return self unless target.respond_to?(:api_resource_type)

      self.class.new(@user, @token, default_resource: target.api_resource_type)
    when ApplicationRecord
      self.class.new(@user, @token, default_resource: target.class.api_resource_type, default_record: target)
    else
      self
    end
  end

  # In the v4 API we ignore the "pretend not to be admin" preference.
  #
  # `resource`, if given, also accepts an "admin.<resource>:<level>" scope or
  # a resource-scoped admin grant (see ResourceGrant) in place of the blanket
  # scope. `record`, if also given, further requires the token's grants (if
  # any) to cover this specific object.
  def admin?(override_pretend: true, resource: @default_resource, record: @default_record)
    @user.admin?(override_pretend: override_pretend) && has_admin_scope?(:write, resource, record)
  end

  def auditor?(override_pretend: true, resource: @default_resource, record: @default_record)
    @user.auditor?(override_pretend: override_pretend) && has_admin_scope?(:read, resource, record)
  end

  # :read requires the auditor role, :write the admin role.
  def can_admin?(level, resource: @default_resource, record: @default_record)
    case level.to_sym
    when :read  then auditor?(resource:, record:)
    when :write then admin?(resource:, record:)
    else false
    end
  end

  # Same auditor-level roles as #auditor?, so gated behind admin:read too.
  # Defined explicitly (not delegated) so the scope check isn't skipped.
  def admin_override_pretend?
    @user.admin_override_pretend? && @token&.scopes&.include?("admin:read")
  end

  # Make `api_context == user_record` work from both sides.
  def ==(other)
    @user == (other.is_a?(self.class) ? other.instance_variable_get(:@user) : other)
  end

  # Make `user_record == api_context` work: AR's == calls
  # `comparison_object.instance_of?(self.class)` on us, then checks id.
  def instance_of?(klass)
    klass == @user.class || super
  end

  def is_a?(klass)
    @user.is_a?(klass) || super
  end
  alias kind_of? is_a?

  private

  def has_admin_scope?(level, resource, record)
    return true if @token&.scopes&.include?("admin:#{level}")
    return false if resource.blank? || @token.nil?
    return false unless @token.scopes&.include?("admin.#{resource}:#{level}") || @token.has_grants_for?(level, resource)

    record.nil? || @token.permits_object?(level, resource, record)
  end

end
