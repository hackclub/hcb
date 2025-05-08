# frozen_string_literal: true

class GSuite
  class RevocationMailerPreview < ActionMailer::Preview
    def revocation_warning
      revocation = GSuite::Revocation.pending.last
      GSuiteMailer.with(g_suite_revocation_id: revocation.id).revocation_warning
    end

    def revocation_one_week_warning
      revocation = GSuite::Revocation.where("scheduled_at < ?", 1.week.from_now).where(one_week_notice_sent: false).pending.last
      GSuite::RevocationMailer.with(g_suite_revocation_id: revocation.id).revocation_one_week_warning
    end

    def notify_of_revocation
      revocation = GSuite::Revocation.revoked.last
      GSuite::RevocationMailer.with(g_suite_revocation_id: revocation.id).notify_of_revocation
    end

    def revocation_canceled
      g_suite = PaperTrail::Version.where(item_type: "GSuite::Revocation", event: "destroy").order(created_at: :desc).first.reify.g_suite
      GSuite::RevocationMailer.with(g_suite_id: g_suite.id).revocation_canceled
    end

  end

end
