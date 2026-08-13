# frozen_string_literal: true

module Pinnable
  extend ActiveSupport::Concern

  MAX_PINS_PER_EVENT = 4

  included do
    scope :pinned, -> { where.not(pinned_at: nil) }

    validate :validate_pinnable, if: :pinned?
    validate :validate_max_pins_for_event, if: -> { pinned? && will_save_change_to_pinned_at? }
  end

  def pinned? = pinned_at.present?

  def pin
    update(pinned_at: Time.current)
  end

  def unpin
    update(pinned_at: nil)
  end

  private

  def validate_pinnable
    unless ledger_item.pinnable?
      errors.add(:base, "At the moment, this transaction can't be pinned.")
    end
  end

  def validate_max_pins_for_event
    # When event is nil, validate_pinnable already catches it via pinnable?, so no error coverage is lost.
    return if event.nil?

    # This validation only runs while transitioning into a pinned state (see the
    # `if:` guard above), so the currently-pinned count from the DB doesn't yet
    # include this record.
    count = event.pinned_ledger_items.size + 1

    if count > MAX_PINS_PER_EVENT
      errors.add(:base, "You can only pin up to four transactions.")
    end
  end
end
