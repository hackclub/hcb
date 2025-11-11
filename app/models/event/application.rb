# frozen_string_literal: true

# == Schema Information
#
# Table name: event_applications
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  address_city        :string
#  address_country     :string
#  address_line1       :string
#  address_line2       :string
#  address_postal_code :string
#  address_state       :string
#  description         :text
#  name                :string
#  notes               :text
#  political           :boolean
#  reference           :string
#  referral_code       :string
#  status              :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  airtable_record_id  :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_event_applications_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Application < ApplicationRecord
    include AASM

    belongs_to :user

    aasm do
      state :draft, initial: true
      state :submitted
      state :approved
      state :rejected
    end

  end

end
