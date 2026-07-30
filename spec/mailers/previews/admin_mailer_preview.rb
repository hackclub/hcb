# frozen_string_literal: true

class AdminMailerPreview < ActionMailer::Preview
  delegate :reminders, to: :AdminMailer

  def blocked_authorization
    AdminMailer
      .with(
        stripe_card: StripeCard.new(
          id: 1,
          name: "AWS Billing",
          event: Event.first,
          user: User.first,
        ).tap(&:readonly!),
        merchant_category: StripeAuthorizationService::FORBIDDEN_MERCHANT_CATEGORIES.first
      )
      .blocked_authorization
  end

  def balance_anomalies
    AdminMailer.balance_anomalies(anomalous_events: Event.all)
  end

  def logical_transaction_anomalies
    AdminMailer.logical_transaction_anomalies(hcb_codes: HcbCode.where(event_id: 2))
  end

end
