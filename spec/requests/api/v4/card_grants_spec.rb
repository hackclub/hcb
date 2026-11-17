# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v4 card grants", type: :request do
  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
  end

  let(:event) { create(:event, plan_type: Event::Plan::CardsOnly) }

  def list_card_grants(user)
    token = create(:api_token, user:)
    get "/api/v4/organizations/#{event.public_id}/card_grants", headers: { "Authorization" => "Bearer #{token.token}" }
  end

  def add_reader(user)
    create(:organizer_position, event:, user:, role: :reader)
    user
  end

  describe "GET /api/v4/organizations/:id/card_grants" do
    it "returns the grants of an organization whose plan excludes transfers" do
      card_grant = create(:card_grant, event:)

      list_card_grants(add_reader(create(:user)))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to eq([card_grant.public_id])
    end

    it "forbids a reader when the plan excludes card grants and there are no grants" do
      list_card_grants(add_reader(create(:user)))

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a user outside a transparent organization" do
      event.update!(is_public: true)
      create(:card_grant, event:)

      list_card_grants(create(:user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
