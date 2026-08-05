# frozen_string_literal: true

# Records, per form, that a client actually rendered it, and requires that
# before accepting the submission.
#
# `invisible_captcha`'s timestamp check already requires that *some* guarded
# form was rendered, but it stores a single global `invisible_captcha_timestamp`
# in the session, so a token seeded by the login page is accepted by any other
# guarded endpoint. That is enough for a client which fetches nothing, and not
# enough for one that fetches the cheapest page and posts somewhere else.
#
# This keys the record on the specific form instead. The token is written
# server side by the action that renders the form and is never sent to the
# client, so it cannot be stripped or forged the way a hidden field could.
# Absence always rejects.
module FormProvenance
  extend ActiveSupport::Concern

  SESSION_KEY = "form_provenance"

  class_methods do
    # Declares that `form` must have been rendered before these actions run.
    # A macro rather than an `included do` block because callback order is
    # source order, and this needs to sit after the `invisible_captcha` macro
    # so the cheaper check runs first.
    def require_rendered_form(form, **options)
      before_action(options) { require_rendered_form!(form) }
    end
  end

  private

  # Called by the action that renders the form.
  def record_rendered_form(form)
    session[SESSION_KEY] = (session[SESSION_KEY] || {}).merge(form.to_s => true)
  end

  def require_rendered_form!(form)
    return if consume_rendered_form(form)

    flash[:error] = "Sorry, something went wrong with that form. Please try again."
    redirect_back fallback_location: root_path
  end

  # Consumed on use, so one render buys one submission.
  def consume_rendered_form(form)
    recorded = session[SESSION_KEY]
    return false unless recorded.is_a?(Hash) && recorded[form.to_s]

    session[SESSION_KEY] = recorded.except(form.to_s)
    true
  end
end
