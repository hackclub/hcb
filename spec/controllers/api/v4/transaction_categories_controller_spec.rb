# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::TransactionCategoriesController do
  render_views

  let(:user) { create(:user) }

  def authenticate(**token_attributes)
    token = create(:api_token, user:, **token_attributes)
    request.headers["Authorization"] = "Bearer #{token.token}"
  end

  describe "#index" do
    it "lists every category and which ones a payment accepts" do
      authenticate

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      categories = response.parsed_body.index_by { |category| category["slug"] }
      expect(categories.keys).to match_array(TransactionCategory::Definition::ALL.keys)
      expect(categories["food-fun"]).to eq("slug" => "food-fun", "label" => TransactionCategory::Definition::ALL["food-fun"].label, "payment_selectable" => true)
      expect(categories["internal-transfer"]["payment_selectable"]).to be(false)
      expect(categories["hcb-revenue"]["payment_selectable"]).to be(false)
    end

    it "lets a restricted token with the transfers scope list them" do
      authenticate(scopes: "restricted transfers:write")

      get :index, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "is forbidden to a restricted token without the transfers scope" do
      authenticate(scopes: "restricted transactions:write")

      get :index, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
