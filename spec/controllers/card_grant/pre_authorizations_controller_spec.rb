# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant::PreAuthorizationsController do
  include SessionSupport
  render_views

  describe "#show" do
    it "doesn't link a non-http product URL" do
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      card_grant = create(:card_grant, event:)
      card_grant.update_columns(user_id: card_grant.stripe_card.user.id)
      # The format validation only checks that an http(s) URL appears somewhere
      # in the string, so this saves.
      pre_authorization = CardGrant::PreAuthorization.create!(card_grant:)
      pre_authorization.update_columns(product_url: "javascript:alert(1)//http://example.com", aasm_state: "submitted")
      create_session(card_grant.user.reload, verified: true)

      get(:show, params: { card_grant_id: card_grant.hashid })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("javascript:alert(1)//http://example.com")
      expect(response.body).not_to include('href="javascript:')
    end
  end
end
