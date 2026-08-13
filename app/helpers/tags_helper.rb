# frozen_string_literal: true

module TagsHelper
  def tag_dom_id(hcb_code, tag, suffix = "")
    "hcb_code_#{hcb_code.hashid}_tag_#{tag.id}#{suffix}"
  end

  def tag_dom_class(*args)
    ".#{tag_dom_id(*args)}"
  end

  # Passes `event` through when the current user gets a tag picker for it, and
  # returns nil otherwise. Callers hand it the ledger's event, which is nil for a
  # subledger — those have no event of their own, so their rows get no picker.
  def taggable_event(event)
    return if event.nil? || event.demo_mode?

    event if organizer_signed_in?(event, as: :member)
  end
end
