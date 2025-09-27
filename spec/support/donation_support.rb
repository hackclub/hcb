# frozen_string_literal: true

module DonationSupport
  def stub_donation_payment_intent_creation
    expect(StripeService::Customer).to(
      receive(:create)
        .and_return(
          Stripe::Customer.construct_from(
            id: "cus_#{SecureRandom.alphanumeric(10)}"
          )
        )
        .at_least(:once)
    )

    payment_intent_id = "pi_#{SecureRandom.alphanumeric(10)}"

    expect(StripeService::PaymentIntent).to(
      receive(:create)
        .and_return(
          Stripe::PaymentIntent.construct_from(
            id: payment_intent_id,
            amount: 12_34,
            amount_received: 0,
            status: "processing",
            client_secret: "#{payment_intent_id}_secret_#{SecureRandom.alphanumeric(10)}"
          )
        )
        .at_least(:once)
    )
  end
end
