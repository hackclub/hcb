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
      create_session(user, verified: true)

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

    it "hides the address and phone number from other organizers" do
      setup_context => { card:, event: }
      other_organizer = create(:user)
      create(:organizer_position, user: other_organizer, event:)
      create_session(other_organizer, verified: true)

      get(:show, params: { id: card.id })

      expect(response).to have_http_status(:ok)

      expect(details_snapshot(response)).to eq(
        [
          "Activation status Active",
          "Card number •••• •••• •••• 9876",
          "Expiration date 02/2030",
          "CVC •••",
          "Type Virtual",
          "Network Visa"
        ]
      )
    end

    it "shows the address and phone number to auditors" do
      setup_context => { card: }
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)

      get(:show, params: { id: card.id })

      expect(response).to have_http_status(:ok)

      expect(details_snapshot(response)).to include(
        "Address 8605 Santa Monica Blvd #86294",
        "City West Hollywood",
        "State CA",
        "ZIP/Postal code 90069",
        "Phone number (855) 625-4225"
      )
    end

    context "when a physical card is still shipping" do
      def setup_shipping_context
        setup_context => { user:, event: }
        design = StripeCard::PersonalizationDesign.create!(event:, color: "black", stripe_name: "Test design", stripe_status: "active")
        design.logo.attach(io: Rails.root.join("spec/fixtures/files/receipt.png").open, filename: "logo.png", content_type: "image/png")
        card = create(
          :stripe_card,
          :with_stripe_id,
          event:,
          stripe_cardholder: create(:stripe_cardholder, user:),
          personalization_design: design,
          initially_activated: false,
          card_type: "physical",
          stripe_shipping_name: user.full_name,
          stripe_shipping_address_line1: "15 Falls Rd",
          stripe_shipping_address_city: "Shelburne",
          stripe_shipping_address_state: "VT",
          stripe_shipping_address_postal_code: "05482",
          stripe_shipping_address_country: "US",
        )

        { user:, event:, card: }
      end

      before do
        allow(Geocoder).to receive(:search).and_return([])
        allow(Stripe::Issuing::Card).to receive(:retrieve).and_return(Stripe::Issuing::Card.construct_from({ shipping: nil }))
      end

      it "hides the shipping address from other organizers" do
        setup_shipping_context => { card:, event: }
        other_organizer = create(:user)
        create(:organizer_position, user: other_organizer, event:)
        create_session(other_organizer, verified: true)

        get(:show, params: { id: card.id })

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("is on the way!")
        expect(response.body).not_to include("15 Falls Rd")
      end

      it "shows the shipping address to the cardholder and auditors" do
        setup_shipping_context => { card:, user: }

        [user, create(:user, :make_auditor)].each do |viewer|
          create_session(viewer, verified: true)

          get(:show, params: { id: card.id })

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("is on the way!")
          expect(response.body).to include("15 Falls Rd")
        end
      end
    end

    it "requires sudo mode to view the details" do
      setup_context => { card:, user: }
      Flipper.enable(:sudo_mode_2015_07_21, user)

      user_session = create_session(user, verified: true)

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

  describe "#freeze" do
    it "does not let a cardholder take over a system freeze" do
      setup_context => { card:, user: }
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      card.update!(stripe_status: "inactive", last_frozen_by: User.system_user)
      create_session(user, verified: true)
      expect(StripeService::Issuing::Card).not_to receive(:update)

      post(:freeze, params: { id: card.id })

      expect(flash[:error]).to eq("Card is already frozen")
      expect(card.reload.last_frozen_by).to eq(User.system_user)
    end
  end
end
