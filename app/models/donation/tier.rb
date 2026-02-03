# frozen_string_literal: true

# == Schema Information
#
# Table name: donation_tiers
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  deleted_at   :datetime
#  description  :text
#  name         :string           not null
#  sort_index   :integer
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
class Donation
  class Tier < ApplicationRecord
    belongs_to :event

    validates :name, :amount_cents, presence: true
    validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
    validate :maximum_tiers_limit
    validate :amount_divisible_by_100

    default_scope { order(sort_index: :asc) }

    acts_as_paranoid

    private

    def maximum_tiers_limit
      return if event.donation_tiers.where.not(id: id).count < 10

      errors.add(:base, "Organization can only have 10 donation tiers")
    end

    def amount_divisible_by_100
      if amount_cents.present? && amount_cents % 100 != 0
        errors.add(:amount_cents, "must be divisible by 100")
      end
    end


  end

end
