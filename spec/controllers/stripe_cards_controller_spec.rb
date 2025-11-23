# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardsController do
  include SessionSupport
  render_views

  def setup_context
    user = create(:user, phone_number: "+18556254225")
    event = create(:event)
    create(:organizer_position, user:, event:)
    card = create(
      :stripe_card,
      :with_stripe_id,
      event:,
      stripe_cardholder: create(:stripe_cardholder, user:),
      initially_activated: true,
      card_type: "virtual",
    )

    { user:, event:, card: }
  end

  def details_snapshot(response)
    response
      .parsed_body
      .css("article.card section.details > *")
      .map { |el| el.text.squish }
  end

  describe "#show" do
    it "renders a stripe card" do
      setup_context => { card:, user: }
      sign_in(user)

      get(:show, params: { id: card.id })

      expect(response).to have_http_status(:ok)

      expect(details_snapshot(response)).to eq(
        [
          "Activation status Active",
          "Card number •••• •••• •••• 9876",
          "Expiration date 02/2030",
          "CVC •••",
          "Address 8605 Santa Monica Blvd #86294",
          "City West Hollywood",
          "State CA",
          "ZIP/Postal code 90069",
          "Phone number (855) 625-4225",
          "Type Virtual",
          "Network Visa"
        ]
      )
    end

    it "requires sudo mode to view the details" do
      setup_context => { card:, user: }
      Flipper.enable(:sudo_mode_2015_07_21, user)

      user_session = sign_in(user)

      travel(3.hours)

      get(:show, params: { id: card.id, show_details: true })

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("Confirm Access")

      # Simulate a reauthentication (this would happen in
      # `LoginsController#reauthenticate` and result in a redirect back to this
      # page)
      login = create(
        :login,
        user:,
        authenticated_with_email: true,
        is_reauthentication: true
      )
      login.update!(user_session:)

      expect(Stripe::Issuing::Card).to(
        receive(:retrieve)
          .with(id: card.stripe_id, expand: ["cvc", "number"])
          .and_return(
            Stripe::Card.construct_from(
              {
                id: card.stripe_id,
                cvc: "123",
                number: "4242424242424242"
              }
            )
          )
      )

      get(:show, params: { id: card.id, show_details: true })

      expect(response).to have_http_status(:ok)

      expect(details_snapshot(response)).to eq(
        [
          "Activation status Active",
          "Card number 4242 4242 4242 4242",
          "Expiration date 02/2030",
          "CVC 123",
          "Address 8605 Santa Monica Blvd #86294",
          "City West Hollywood",
          "State CA",
          "ZIP/Postal code 90069",
          "Phone number (855) 625-4225",
          "Type Virtual",
          "Network Visa"
        ]
      )
    end
  end
end
