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
#  airtable_status     :string
#  description         :text
#  name                :string
#  notes               :text
#  political           :boolean
#  referral_code       :string
#  referrer            :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  airtable_record_id  :string
#  event_id            :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_event_applications_on_event_id  (event_id)
#  index_event_applications_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Application < ApplicationRecord
    include AASM

    belongs_to :user, optional: false
    belongs_to :event

    aasm do
      state :draft, initial: true
      state :submitted
      state :under_review
      state :approved
      state :rejected
    end

  end

end
