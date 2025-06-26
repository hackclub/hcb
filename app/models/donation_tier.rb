# frozen_string_literal: true

# == Schema Information
#
# Table name: donation_tiers
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  deleted_at   :datetime
#  description  :text
#  image_url    :string
#  name         :string           not null
#  position     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  event_id     :bigint           not null
#
# Indexes
#
#  index_donation_tiers_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class DonationTier < ApplicationRecord
  belongs_to :event

  validates :name, :amount_cents, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  default_scope { order(position: :asc) }

  acts_as_paranoid

end
