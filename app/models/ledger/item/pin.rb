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

      validates :ledger_item_id, uniqueness: true
      validate :validate_max_pins_for_event, on: :create
      validate :validate_pinnable, on: :create

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

    end

  end

end
