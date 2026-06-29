# frozen_string_literal: true

class PaymentMailerPreview < ActionMailer::Preview
  def missing_payout_method
    PaymentMailer.with(payment: Payment.last, initial: true).missing_payout_method
  end

end
