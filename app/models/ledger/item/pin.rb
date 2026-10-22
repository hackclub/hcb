# frozen_string_literal: true

class Ledger
  class Item
    module Pin
      extend ActiveSupport::Concern

      MAX_PINS_PER_EVENT = 4

      included do
        scope :pinned, -> { where.not(pinned_at: nil) }

        validate :validate_pinnable, if: :pinned?
        validate :validate_max_pins_for_event, if: -> { pinned? && will_save_change_to_pinned_at? }
        validate :validate_pinned_on_primary_ledger, if: :pinned?

        # A remapped item is no longer the same event's transaction, so any existing
        # pin (which is scoped to the event it was pinned under) shouldn't carry over.
        before_save :unpin_on_remap
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

      def validate_pinned_on_primary_ledger
        errors.add(:base, "Only the primary mapping for a ledger item can be pinned.") unless on_primary_ledger?
      end

      def unpin_on_remap
        self.pinned_at = nil if pinned? && will_save_change_to_ledger_id?
      end
    end

  end

end
