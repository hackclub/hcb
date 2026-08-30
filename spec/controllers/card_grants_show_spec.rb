# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantsController do
  include SessionSupport
  render_views

  describe "#show" do
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    it "renders the spending guide for the grantee" do
      card_grant = create(:card_grant, event:)
      create_session(card_grant.user, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pay with your card")
      expect(response.body).to include("What you can spend it on")
      expect(response.body).to include("Where it&#39;s gone")
    end

    it "renders the activation prompt before the card exists" do
      card_grant = create(:card_grant, event:)
      card_grant.update!(stripe_card: nil)
      create_session(card_grant.user, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Activate your grant card")
      expect(response.body).not_to include("Pay with your card")
    end

    it "renders for an organizer without exposing the card numbers" do
      organizer = create(:user)
      card_grant = create(:card_grant, event:)
      create(:organizer_position, user: organizer, event:)
      create_session(organizer, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The card")
      expect(response.body).not_to include("Show card details")
      expect(response.body).not_to include("Billing address")
    end
  end
end
