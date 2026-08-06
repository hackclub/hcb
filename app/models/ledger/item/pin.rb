# frozen_string_literal: true

# == Schema Information
#
# Table name: ledger_item_pins
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ledger_item_id :bigint           not null
#
# Indexes
#
#  index_ledger_item_pins_on_ledger_item_id  (ledger_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#
class Ledger
  class Item
    class Pin < ApplicationRecord
      self.table_name = "ledger_item_pins"

      belongs_to :ledger_item, class_name: "Ledger::Item"
      has_one :hcb_code_pin, class_name: "HcbCode::Pin", foreign_key: :ledger_item_pin_id, inverse_of: :ledger_item_pin

      # Internal flag set on a Pin built by HcbCode::Pin#sync_ledger_item_pin, so this
      # side's own sync callbacks below don't mirror it right back and recurse forever.
      attr_accessor :skip_hcb_code_pin_sync

      validate :validate_max_pins_for_event, on: :create
      validate :validate_pinnable, on: :create

      after_create :sync_hcb_code_pin, unless: :skip_hcb_code_pin_sync
      # before_destroy, not after_destroy: hcb_code_pins.ledger_item_pin_id FKs into this
      # table, so the referencing row must be gone before this row's DELETE executes.
      before_destroy :destroy_hcb_code_pin, unless: :skip_hcb_code_pin_sync

      def event
        ledger_item.primary_ledger&.event
      end

      private

      def validate_max_pins_for_event
        # When event is nil, validate_pinnable already catches it via pinnable?, so no error coverage is lost.
        return if event.nil?

        count = event.pinned_ledger_items.size
        count += 1 if new_record?

        if count > 4
          errors.add(:base, "You can only pin up to four transactions.")
        end
      end

      def validate_pinnable
        unless ledger_item.pinnable?
          errors.add(:base, "At the moment, this transaction can't be pinned.")
        end
      end

      # Ledger::Item::Pin is what HcbCode::Pin is being migrated to; keep a mirror
      # row there so both models stay usable during the transition. Skipped (see
      # the `unless:` guards above) when this pin was itself created as the
      # mirror of an HcbCode::Pin, so the two callbacks don't ping-pong forever.
      def sync_hcb_code_pin
        hcb_code = ledger_item.hcb_code
        return if hcb_code.nil?

        pin = HcbCode::Pin.new(event:, hcb_code:, ledger_item_pin: self, skip_ledger_item_pin_sync: true)
        # This record (the source of truth for this create) already enforced
        # max-pins-for-event/pinnable?; don't re-validate and risk the mirror
        # rejecting a pin that was just accepted.
        pin.save!(validate: false)
      end

      def destroy_hcb_code_pin
        return unless hcb_code_pin

        hcb_code_pin.skip_ledger_item_pin_sync = true
        hcb_code_pin.destroy
      end

    end

  end

end
