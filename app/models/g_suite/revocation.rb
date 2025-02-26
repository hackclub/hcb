# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suite_revocations
#
#  id           :bigint           not null, primary key
#  aasm_state   :string
#  other_reason :text
#  reason       :integer          default(0), not null
#  scheduled_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  g_suite_id   :bigint           not null
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

    enum :reason, prefix: :because_of

    belongs_to :g_suite

    validate :other_reason, presence: false, unless: :because_of_other?

    aasm do
      state :warning, initial: true # 2 weeks from warning to pending revocation
      state :pending_revocation # adds to a list where HCB ops can review and
      # click "revoke" to delete the g_suite and all associated data/accounts

      event :mark_pending_revocation do
        transitions from: :warning, to: :pending_revocation
      end
    end

    after_create_commit do
      GSuiteMailer.with(g_suite_id: g_suite.id, g_suite_revocation_id: self.id).notify_of_pending_revocation.deliver_later
    end

    after_initialize do
      self.scheduled_at = 2.weeks.from_now
    end

  end

end
