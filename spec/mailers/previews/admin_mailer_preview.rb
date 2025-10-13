# frozen_string_literal: true

class AdminMailerPreview < ActionMailer::Preview
  delegate :reminders, to: :AdminMailer

  def weekly_ysws_event_summary
    @events = Event.last(3)
    AdminMailer.with(events: @events).weekly_ysws_event_summary
  end

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

end
