# frozen_string_literal: true

# == Schema Information
#
# Table name: donation_goals
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer          not null
#  deleted_at     :datetime
#  tracking_since :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_id       :bigint           not null
#
# Indexes
#
#  index_donation_goals_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Donation
  class Goal < ApplicationRecord
    acts_as_paranoid
    validates_as_paranoid
    has_paper_trail

    belongs_to :event

    validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :tracking_since, presence: true

    validates_uniqueness_of_without_deleted :event_id

    after_initialize do
      self.tracking_since ||= Time.current
    end

    def progress_amount_cents
      event.donations.succeeded.where(created_at: tracking_since..).sum(:amount_received)
    end

  end

end
