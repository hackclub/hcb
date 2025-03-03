# frozen_string_literal: true

# == Schema Information
#
# Table name: lob_addresses
#
#  id          :bigint           not null, primary key
#  address1    :string
#  address2    :string
#  city        :string
#  country     :string
#  description :text
#  name        :string
#  state       :string
#  zip         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :bigint
#  lob_id      :string
#
# Indexes
#
#  index_lob_addresses_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class LobAddress < ApplicationRecord
  # [@garyhtou] This model is deprecated and now read-only.
  after_initialize :readonly!
  # LobAddress was last used March 2023 when we used Lob (lob.com) to print and
  # mail checks.

  has_many :checks
  belongs_to :event

  def address_text
    "#{address1} #{address2} - #{city}, #{state} #{zip}"
  end

end
