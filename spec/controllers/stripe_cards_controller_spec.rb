# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardsController do
  include SessionSupport
  render_views

  describe "#show" do
    it "renders a stripe card" do
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

      sign_in(user)

      get(:show, params: { id: card.id })

      expect(response).to have_http_status(:ok)

      details =
        response
        .parsed_body
        .css("article.card section.details > *")
        .map { |el| el.text.gsub(/\s+/, " ").strip }

      expect(details).to eq(
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
  end
end
