# frozen_string_literal: true

# == Schema Information
#
# Table name: applications
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  address_city        :string           not null
#  address_country     :string           not null
#  address_line1       :string           not null
#  address_line2       :string
#  address_postal_code :string           not null
#  address_state       :string           not null
#  description         :text             not null
#  name                :string           not null
#  notes               :text
#  political           :boolean          not null
#  reference           :string           not null
#  referral_code       :string
#  status              :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  airtable_record_id  :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_applications_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Application < ApplicationRecord
  belongs_to :user

  aasm do
    state :submitted, initial: true
    state :approved
    state :rejected
  end

end
