# frozen_string_literal: true

# Internal alerts for HCB engineers, posted to a Slack channel via a
# Slack-posting email address. One action per alert type, following the
# same shape as AdminMailer's engineer-facing actions (balance_anomalies,
# fee_anomalies, ...), but kept separate since these aren't admin-workflow
# emails.
#
# Counts/suppressed are passed in by the caller (captured at the moment of
# the transition) rather than queried here: this runs inside an async
# MailDeliveryJob, an arbitrary interval after the transition that triggered
# it, so querying live state here would describe "now," not the transition
# being reported on.
class EngineeringAlertMailer < ApplicationMailer
  default to: -> { Credentials.fetch(:SLACK_HCB_ENGR_ALERTS_EMAIL) }

  def cards_locked(user:, overdue_count:, suppressed:)
    @user = user
    @count = overdue_count
    @suppressed = suppressed
    mail subject: "[Card Locking] #{@user.name}'s cards were locked"
  end

  def cards_unlocked(user:, remaining_overdue_count:, suppressed:)
    @user = user
    @remaining_overdue_count = remaining_overdue_count
    @suppressed = suppressed

    # An unlock with overdue charges still outstanding is only a violated
    # precondition when it's NOT from admin suppression -- suppression is a
    # supported action that unlocks without resolving receipts by design
    # (see UserService::UpdateCardLocking#run and users_controller.rb's
    # suppress_card_locking). Report it as an anomaly (reported in
    # production, raised loudly in development/test) only in the genuine
    # case.
    if @remaining_overdue_count.positive? && !@suppressed
      Rails.error.unexpected(
        # user_id kept out of the message (only in context) so AppSignal
        # groups every occurrence as one error, not one per user.
        "[Card Locking] unlocked with #{@remaining_overdue_count} overdue charges remaining",
        context: { user_id: user.id, remaining_overdue_count: @remaining_overdue_count }
      )
    end

    mail subject: "[Card Locking] #{@user.name}'s cards were unlocked"
  end

end
