# frozen_string_literal: true

# Wraps a User for the Pundit policy context in the v4 API with respect to admin scopes and admin priviledges
class ApiAdminContext
  delegate_missing_to :@user

  def initialize(user, token)
    @user = user
    @token = token
  end

  # In the v4 API we ignore the "pretend not to be admin" preference
  def admin?(override_pretend: true)
    @user.admin?(override_pretend: override_pretend) && @token&.scopes&.include?("admin:write")
  end

  # In the v4 API we ignore the "pretend not to be admin" preference
  def auditor?(override_pretend: true)
    @user.auditor?(override_pretend: override_pretend) && @token&.scopes&.include?("admin:read")
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

end
