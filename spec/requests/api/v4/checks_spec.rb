# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v4 checks", type: :request do
  let(:event) { create(:event, :with_positive_balance) }
  let(:check) do
    event.increase_checks.create!(
      amount: 100_00,
      memo: "Test memo",
      payment_for: "Snacks",
      recipient_name: "Orpheus",
      recipient_email: "orpheus@example.com",
      address_line1: "15 Falls Rd.",
      address_city: "Shelburne",
      address_state: "VT",
      address_zip: "05482"
    )
  end

  def get_check(user)
    token = create(:api_token, user:)
    get "/api/v4/checks/#{check.public_id}", headers: { "Authorization" => "Bearer #{token.token}" }
  end

  describe "GET /api/v4/checks/:id" do
    it "returns the check to a reader of its organization" do
      user = create(:user)
      create(:organizer_position, event:, user:, role: :reader)

      get_check(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(check.public_id)
    end

    it "forbids a user outside a transparent organization" do
      event.update!(is_public: true)

      get_check(create(:user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
