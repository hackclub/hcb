# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::StripeCards::PersonalizationDesignsController do
  render_views

  let(:user) { create(:user) }

  def create_design(**attrs)
    StripeCard::PersonalizationDesign.create!(
      color: "black",
      stripe_status: "active",
      stripe_name: "Design #{SecureRandom.hex(3)}",
      **attrs
    )
  end

  def authenticate(as: user, scopes: "")
    token = create(:api_token, user: as, scopes:)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  describe "#index" do
    context "without an event_id" do
      it "returns only active common designs" do
        authenticate
        common = create_design(common: true)
        create_design(event: create(:event))
        create_design(common: true, stripe_status: "inactive")

        get(:index, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.pluck("id")).to eq([common.id])
      end

      it "includes unlisted designs for an admin token with admin:read" do
        authenticate(as: create(:user, access_level: :admin), scopes: "admin:read")
        common = create_design(common: true)
        unlisted = create_design

        get(:index, as: :json)

        expect(response.parsed_body.pluck("id")).to contain_exactly(common.id, unlisted.id)
      end

      it "hides unlisted designs from an admin whose token lacks admin:read" do
        authenticate(as: create(:user, access_level: :admin), scopes: "")
        common = create_design(common: true)
        create_design

        get(:index, as: :json)

        expect(response.parsed_body.pluck("id")).to eq([common.id])
      end
    end

    context "with an event_id" do
      it "returns the event's designs plus common designs for a member" do
        event = create(:event)
        create(:organizer_position, user:, event:)
        authenticate
        common = create_design(common: true)
        own = create_design(event:)
        create_design(event: create(:event))

        get(:index, params: { event_id: event.friendly_id }, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.pluck("id")).to contain_exactly(common.id, own.id)
      end

      it "returns 403 for a non-member" do
        authenticate
        event = create(:event)

        get(:index, params: { event_id: event.friendly_id }, as: :json)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq("error" => "not_authorized")
      end
    end
  end

  describe "routing" do
    it "routes cards/designs ahead of cards/:id" do
      expect(get: "/api/v4/cards/designs").to route_to(controller: "api/v4/stripe_cards/personalization_designs", action: "index", format: :json)
    end

    it "routes the nested organization path" do
      expect(get: "/api/v4/organizations/org_123/cards/designs").to route_to(controller: "api/v4/stripe_cards/personalization_designs", action: "index", event_id: "org_123", format: :json)
    end

    it "keeps the deprecated card_designs path" do
      expect(get: "/api/v4/cards/card_designs").to route_to(controller: "api/v4/stripe_cards/personalization_designs", action: "index", format: :json)
    end
  end
end
