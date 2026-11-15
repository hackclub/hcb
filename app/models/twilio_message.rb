# frozen_string_literal: true

# == Schema Information
#
# Table name: twilio_messages
#
#  id                 :bigint           not null, primary key
#  body               :text
#  from               :text
#  raw_data           :jsonb
#  to                 :text
#  twilio_account_sid :text
#  twilio_sid         :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class TwilioMessage < ApplicationRecord
  validates_presence_of :to, :from, :body, :twilio_sid, :twilio_account_sid

  has_one :outgoing_twilio_message, required: false

  has_one :hcb_code, through: :outgoing_twilio_message

  has_many_attached :files

end
