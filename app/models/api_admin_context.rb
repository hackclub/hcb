# frozen_string_literal: true

# Wraps a User for the Pundit policy context in the v4 API with respect to admin scopes and admin priviledges
class ApiAdminContext
  delegate_missing_to :@user
  attr_reader :token

  def initialize(user, token)
    @user = user
    @token = token
  end

  # In the v4 API we ignore the "pretend not to be admin" preference.
  #
  # `resource`, if given, also accepts a resource-scoped admin grant (see
  # ResourceGrant) in place of the blanket "admin:write" scope, e.g.
  # resource: "comments". `record`, if also given, further requires that
  # grant to cover this specific object.
  def admin?(override_pretend: true, resource: nil, record: nil)
    @user.admin?(override_pretend: override_pretend) && has_admin_scope?(:write, resource, record)
  end

  def auditor?(override_pretend: true, resource: nil, record: nil)
    @user.auditor?(override_pretend: override_pretend) && has_admin_scope?(:read, resource, record)
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
    return false unless @token.has_grants_for?(level, resource)

    record.nil? || @token.permits_object?(level, resource, record)
  end

end
