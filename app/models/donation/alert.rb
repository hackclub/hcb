# frozen_string_literal: true

#
# == Schema Information
#
# Table name: donation_alerts
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  alert_message :text
#  alert_name    :string
#  amount_cents  :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  event_id      :bigint           not null
#
# Indexes
#
#  index_donation_alerts_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#

class Donation
  class Alert < ApplicationRecord
    self.table_name = "donation_alerts"

    belongs_to :event
    has_and_belongs_to_many :users,
                            join_table: "donation_alerts_users",
                            foreign_key: "donation_alert_id",
                            association_foreign_key: "user_id"

    validates :amount_cents, presence: true, numericality: { greater_than: 0 }
    validates :alert_name, presence: true

    scope :active, -> { where(active: true) }

    def subscribe(user)
      users << user unless users.include?(user)
    end

    def unsubscribe(user)
      users.delete(user)
    end

    def subscribed?(user)
      users.include?(user)
    end

  end

end
