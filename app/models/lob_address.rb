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
  has_many :checks
  belongs_to :event

  before_create :default_values

  def set_fields_from_lob_address(lob_address)
    self.description = lob_address["description"]
    self.name = lob_address["name"]
    self.address1 = lob_address["address_line1"]
    self.address2 = lob_address["address_line2"]
    self.city = lob_address["address_city"]
    self.state = lob_address["address_state"]
    self.zip = lob_address["address_zip"]
    self.country = lob_address["address_country"]
    self.lob_id = lob_address["id"]
  end

  def address_text
    "#{address1} #{address2} - #{city}, #{state} #{zip}"
  end

  private

  def default_values
    self.country = "US"
    self.description = "#{name} - #{address1}"
  end

end
