# frozen_string_literal: true

# == Schema Information
#
# Table name: governance_admin_transfer_limit_boosts
#
#  id                                 :bigint           not null, primary key
#  amount_cents                       :integer          not null
#  expires_at                         :datetime         not null
#  reason                             :text             not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  governance_admin_transfer_limit_id :bigint           not null
#  granted_by_id                      :bigint           not null
#
# Indexes
#
#  idx_on_governance_admin_transfer_limit_id_8df1f30b3a           (governance_admin_transfer_limit_id)
#  index_governance_admin_transfer_limit_boosts_on_granted_by_id  (granted_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (governance_admin_transfer_limit_id => governance_admin_transfer_limits.id)
#  fk_rails_...  (granted_by_id => users.id)
#
module Governance
  module Admin
    module Transfer
      class Limit
        class Boost < ApplicationRecord
          MINIMUM_DURATION_IN_HOURS = (Limit::WINDOW_DURATION / 1.hour).to_i
          DEFAULT_DURATION_IN_HOURS = 36
          MAXIMUM_DURATION_IN_HOURS = 7 * 24

          has_paper_trail

          belongs_to :limit,
                     class_name: "Governance::Admin::Transfer::Limit",
                     foreign_key: "governance_admin_transfer_limit_id",
                     inverse_of: :boosts
          belongs_to :granted_by, class_name: "User"

          attribute :duration_in_hours, :integer, default: DEFAULT_DURATION_IN_HOURS
          validates :duration_in_hours, numericality: { only_integer: true, in: MINIMUM_DURATION_IN_HOURS..MAXIMUM_DURATION_IN_HOURS }, on: :create
          before_validation :set_expires_at, on: :create

          monetize :amount_cents
          validates :amount_cents, presence: true, numericality: { greater_than: 0 }
          validates :reason, presence: true
          validates :expires_at, presence: true

          scope :active, -> { where(arel_table[:expires_at].gt(Time.current)) }

          def active?
            expires_at.future?
          end

          def revoke!
            update!(expires_at: Time.current)
          end

          private

          def set_expires_at
            self.expires_at = duration_in_hours.hours.from_now if duration_in_hours
          end

        end

      end
    end
  end
end
