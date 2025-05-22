# frozen_string_literal: true

class GSuite
  class SendOneWeekRevocationWarningJob < ApplicationJob
    queue_as :low

    def perform
      GSuite::Revocation.where("scheduled_at < ?", 1.week.from_now).where(one_week_notice_sent: false).pending.find_each(batch_size: 100) do |revocation|
        if revocation.g_suite.immune_to_revocation?
          revocation.destroy!
          next
        end
        GSuite::RevocationMailer.with(g_suite_revocation_id: revocation.id).revocation_one_week_warning.deliver_later
        revocation.update!(one_week_notice_sent: true)
      end
    end

  end

end

module GSuiteJob
  SendOneWeekRevocationWarning = GSuite::SendOneWeekRevocationWarningJob
end
