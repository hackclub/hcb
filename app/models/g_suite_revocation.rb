# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suite_revocations
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string
#  invalid_dns         :boolean          default(FALSE), not null
#  no_account_activity :boolean          default(FALSE), not null
#  other               :boolean          default(FALSE), not null
#  other_reason        :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  g_suite_id          :bigint           not null
#
# Indexes
#
#  index_g_suite_revocations_on_g_suite_id  (g_suite_id)
#
# Foreign Keys
#
#  fk_rails_...  (g_suite_id => g_suites.id)
#
class GSuiteRevocation < ApplicationRecord
  has_paper_trail
  acts_as_paranoid

  include AASM

  belongs_to :g_suite

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

end
