# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantsController do
  include SessionSupport
  render_views

  describe "#show" do
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    it "renders the card, rules and transactions for the grantee" do
      card_grant = create(:card_grant, event:)
      card_grant.update_columns(user_id: card_grant.stripe_card.user.id)
      create_session(card_grant.user.reload, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Billing address")
      expect(response.body).to include("Show details")
      expect(response.body).to include("What you can spend it on")
      expect(response.body).to include("Upload receipts for each purchase")
    end

    it "renders the activation prompt before the card exists" do
      card_grant = create(:card_grant, event:)
      card_grant.update!(stripe_card: nil)
      create_session(card_grant.user, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Activate your grant card")
      expect(response.body).not_to include("Billing address")
    end

    it "renders for an organizer without exposing the card details" do
      organizer = create(:user)
      card_grant = create(:card_grant, event:)
      create(:organizer_position, user: organizer, event:)
      create_session(organizer, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Virtual card")
      expect(response.body).to include("Spending controls")
      expect(response.body).not_to include("Billing address")
      expect(response.body).not_to include("Show details")
    end

    it "shows defrost copy, not the freeze copy, once the grantee's card is frozen" do
      card_grant = create(:card_grant, event:)
      card_grant.update_columns(user_id: card_grant.stripe_card.user.id)
      card_grant.stripe_card.update_columns(stripe_status: "inactive")
      create_session(card_grant.user.reload, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response.body).to include("Card frozen")
      expect(response.body).not_to include("Pause spending instantly")
    end

    it "explains why cancel is disabled for a member who can't cancel" do
      create(:organizer_position, event:, role: :manager)
      member = create(:user)
      create(:organizer_position, user: member, event:, role: :member)
      card_grant = create(:card_grant, event:)
      create_session(member, verified: true)

      get(:show, params: { id: card_grant.hashid })

      expect(response.body).to include("You don&#39;t have permission to perform this action")
      expect(response.body).not_to include("Return the balance to")
    end
  end
end
