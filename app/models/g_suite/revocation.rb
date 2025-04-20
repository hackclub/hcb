# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suite_revocations
#
#  id                   :bigint           not null, primary key
#  aasm_state           :string
#  one_week_notice_sent :boolean          default(FALSE), not null
#  other_reason         :text
#  reason               :integer          default(NULL), not null
#  scheduled_at         :datetime         not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  g_suite_id           :bigint           not null
#
# Indexes
#
#  index_g_suite_revocations_on_g_suite_id  (g_suite_id)
#
# Foreign Keys
#
#  fk_rails_...  (g_suite_id => g_suites.id)
#

class GSuite
  class Revocation < ApplicationRecord
    has_paper_trail
    acts_as_paranoid

    include AASM

    enum :reason, { invalid_dns: 0, accounts_inactive: 1, other: 2 }, prefix: :because_of

    belongs_to :g_suite

    validates :other_reason, presence: false, unless: :because_of_other?
    validates :other_reason, presence: true, if: :because_of_other?

    aasm do
      state :pending, initial: true # 2 weeks from warning to pending revocation
      state :revoked # adds to a list where HCB ops can review and
      # click "revoke" to delete the g_suite and all associated data/accounts

      event :mark_revoked do
        transitions from: :pending, to: :revoked

        after do
          GSuiteMailer.with(g_suite_id: g_suite.id).notify_of_revocation.deliver_later
        end
      end
    end

    after_create_commit do
      return unless pending?

      GSuiteMailer.with(g_suite_id: g_suite.id, g_suite_revocation_id: self.id).revocation_warning.deliver_later
    end

    before_validation on: :create do
      self.scheduled_at = 2.weeks.from_now
    end

    after_destroy_commit do
      unless destroyed_by_association.present?
        GSuiteMailer.with(g_suite_id: g_suite.id).revocation_canceled.deliver_later
      end
    end

  end

end
