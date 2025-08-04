# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantsController do
  include SessionSupport
  render_views

  describe "#new" do
    it "renders successfully" do
      user = create(:user)
      event = create(:event)
      create(:organizer_position, user:, event:)
      sign_in(user)

      expect(event.card_grant_setting).to be_nil

      get(:new, params: { event_id: event.friendly_id })

      expect(response).to have_http_status(:ok)
      expect(event.reload.card_grant_setting).to be_present
    end
  end

  describe "#create" do
    it "creates a card grant" do
      user = create(:user)
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      create(:organizer_position, user:, event:)
      sign_in(user)

      post(
        :create,
        params: {
          event_id: event.friendly_id,
          card_grant: {
            amount_cents: "123.45",
            email: "recipient@example.com",
            keyword_lock: "some keywords",
            purpose: "Raffle prize",
            one_time_use: "true",
            pre_authorization_required: "true",
            instructions: "Here's a card grant for your raffle prize"
          }
        }
      )

      expect(response).to redirect_to(event_transfers_path(event))
      card_grant = event.card_grants.sole
      expect(card_grant.amount_cents).to eq(123_45)
      expect(card_grant.email).to eq("recipient@example.com")
      expect(card_grant.keyword_lock).to eq("some keywords")
      expect(card_grant.purpose).to eq("Raffle prize")
      expect(card_grant.one_time_use).to eq(true)
      expect(card_grant.pre_authorization_required).to eq(true)
      expect(card_grant.instructions).to eq("Here's a card grant for your raffle prize")
    end
  end
end
