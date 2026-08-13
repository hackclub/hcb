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

  # Which of `hcb_codes` are mapped to `event`, as a set of HCB code strings.
  #
  # This answers per row what `HcbCode#events.include?(event)` would, but for the
  # whole table in two queries rather than two per row. The associations are keyed
  # on the `hcb_code` string rather than the id.
  def hcb_codes_mapped_to(event, hcb_codes)
    codes = hcb_codes.compact.map(&:hcb_code).uniq
    return Set.new if codes.empty? || event.nil?

    settled = CanonicalTransaction.where(hcb_code: codes)
                                  .joins(:canonical_event_mapping)
                                  .where(canonical_event_mappings: { event_id: event.id })
                                  .pluck(:hcb_code)

    pending = CanonicalPendingTransaction.where(hcb_code: codes)
                                         .joins(:canonical_pending_event_mapping)
                                         .where(canonical_pending_event_mappings: { event_id: event.id })
                                         .pluck(:hcb_code)

    Set.new(settled).merge(pending)
  end
end
