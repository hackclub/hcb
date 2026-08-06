# frozen_string_literal: true

# == Schema Information
#
# Table name: hcb_code_pins
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  event_id           :bigint
#  hcb_code_id        :bigint
#  ledger_item_pin_id :bigint
#
# Indexes
#
#  index_hcb_code_pins_on_event_id            (event_id)
#  index_hcb_code_pins_on_hcb_code_id         (hcb_code_id) UNIQUE
#  index_hcb_code_pins_on_ledger_item_pin_id  (ledger_item_pin_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#  fk_rails_...  (ledger_item_pin_id => ledger_item_pins.id)
#

class HcbCode
  class Pin < ApplicationRecord
    belongs_to :hcb_code
    belongs_to :event
    belongs_to :ledger_item_pin, class_name: "Ledger::Item::Pin", optional: true, inverse_of: :hcb_code_pin

    # Internal flag set on a Pin built by Ledger::Item::Pin#sync_hcb_code_pin, so this
    # side's own sync callbacks below don't mirror it right back and recurse forever.
    attr_accessor :skip_ledger_item_pin_sync

    validate :validate_max_pins_for_event, on: :create
    validate :validate_pinnable, on: :create

    after_create :sync_ledger_item_pin, unless: -> { ledger_item_pin_id? || skip_ledger_item_pin_sync }
    # after_destroy, not before: this row is the FK source (ledger_item_pin_id), so it
    # must be gone before the referenced Ledger::Item::Pin row can be deleted.
    after_destroy :destroy_ledger_item_pin, unless: :skip_ledger_item_pin_sync

    private

    def validate_max_pins_for_event
      count = event.pinned_hcb_codes.size
      count += 1 if new_record?

      if count > 4
        errors.add(:base, "You can only pin up to four transactions.")
      end
    end

    def validate_pinnable
      unless hcb_code.pinnable?
        errors.add(:base, "At the moment, this transaction can't be pinned.")
      end
    end

    # HcbCode::Pin is being migrated to Ledger::Item::Pin; keep a mirror row so
    # both models stay usable during the transition. Skipped (see the `unless:`
    # guards above) when this pin was itself created as the mirror of a
    # Ledger::Item::Pin, so the two callbacks don't ping-pong forever.
    def sync_ledger_item_pin
      ledger_item = hcb_code.ledger_item
      return if ledger_item.nil?

      pin = Ledger::Item::Pin.new(ledger_item:, skip_hcb_code_pin_sync: true)
      # This record (the source of truth for this create) already enforced
      # max-pins-for-event/pinnable?; don't re-validate and risk the mirror
      # rejecting a pin that was just accepted.
      pin.save!(validate: false)
      update_column(:ledger_item_pin_id, pin.id)
    end

    def destroy_ledger_item_pin
      return unless ledger_item_pin

      ledger_item_pin.skip_hcb_code_pin_sync = true
      ledger_item_pin.destroy
    end

  end

end
