# frozen_string_literal: true

# == Schema Information
#
# Table name: card_grant_settings
#
#  id                    :bigint           not null, primary key
#  category_lock         :string
#  expiration_preference :integer          default("1 year"), not null
#  invite_message        :string
#  keyword_lock          :string
#  merchant_lock         :string
#  event_id              :bigint           not null
#
# Indexes
#
#  index_card_grant_settings_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class CardGrantSetting < ApplicationRecord
  belongs_to :event
  serialize :merchant_lock, coder: CommaSeparatedCoder # convert comma-separated merchant list to an array
  serialize :category_lock, coder: CommaSeparatedCoder
  alias_attribute :allowed_merchants, :merchant_lock
  alias_attribute :allowed_categories, :category_lock
  has_many :card_grants, through: :event

  enum :expiration_preference, {
    "90 days": 90,
    "6 months": 183,
    "1 year": 365,
    "2 years": 365 * 2
  }, prefix: :expires_after

end
