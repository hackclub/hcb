# frozen_string_literal: true

# == Schema Information
#
# Table name: hcb_code_pins
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :bigint
#  hcb_code_id :bigint
#
# Indexes
#
#  index_hcb_code_pins_on_event_id     (event_id)
#  index_hcb_code_pins_on_hcb_code_id  (hcb_code_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#

class HcbCode
  class Pin < ApplicationRecord
    belongs_to :hcb_code
    belongs_to :event
    validate :validate_max_pins_for_event, on: :create
    validate :validate_pinnable, on: :create

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

  end

end
