# frozen_string_literal: true

# Wraps a User for the Pundit policy context in the v4 API with respect to admin scopes and admin priviledges
class ApiAdminContext
  delegate_missing_to :@user

  def initialize(user, token, resource: nil)
    @user = user
    @token = token
    @resource = resource
  end

  # In the v4 API we ignore the "pretend not to be admin" preference
  def admin?(override_pretend: true)
    @user.admin?(override_pretend: override_pretend) && admin_scope?("write")
  end

  # In the v4 API we ignore the "pretend not to be admin" preference
  def auditor?(override_pretend: true)
    @user.auditor?(override_pretend: override_pretend) && admin_scope?("read")
  end

  # Same auditor-level roles as #auditor?, so gated behind admin:read too.
  # Defined explicitly (not delegated) so the scope check isn't skipped.
  def admin_override_pretend?
    @user.admin_override_pretend? && admin_scope?("read")
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

  # `admin:read` / `admin:write` grant admin access across the whole API.
  # `admin:<resource>:read` / `admin:<resource>:write` scopes grant the
  # same level for one resource only. 
  # Both are checked independently of the `restricted` scope.
  def admin_scope?(level)
    scopes = @token&.scopes || []

    scopes.include?("admin:#{level}") ||
      (@resource.present? && scopes.include?("admin:#{@resource}:#{level}"))
  end

end
