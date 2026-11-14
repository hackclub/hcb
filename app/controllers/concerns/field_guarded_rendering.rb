# frozen_string_literal: true

# Checks guarded fields (see FieldGuard) while a response renders, for the same
# user that `authorize` checks.
module FieldGuardedRendering
  def render_to_body(options = {})
    FieldGuard.enforce(pundit_user) { super }
  end

  protected

  # `policy(record)` in views and controllers. Policies always read real values.
  # Protected, like Pundit's own, so it never counts as a controller action.
  def policy(record)
    FieldGuard::UnguardedPolicy.new(super)
  end

end
