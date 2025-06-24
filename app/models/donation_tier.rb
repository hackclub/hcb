class DonationTier < ApplicationRecord
  belongs_to :event

  validates :name, :amount_cents, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  default_scope { order(position: :asc) }

  acts_as_paranoid
end
