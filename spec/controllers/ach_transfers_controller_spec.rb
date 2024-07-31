# frozen_string_literal: true

require "rails_helper"

describe AchTransfersController do
  describe "show" do
    it "redirects to hcb code" do
      event = create(:event)
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      ach_transfer = create(:ach_transfer, event:)
      get :show, params: { id: ach_transfer.id }
      expect(response).to redirect_to(hcb_code_path(ach_transfer.local_hcb_code.hashid))
    end
  end

  describe "validate_routing_number" do
    before do
      # janky way of signing in for tests, we basically override the call in sessions_helper that checks for current_user to return this test user
      user = create(:user)
      allow(controller).to receive(:current_user).and_return(user)
    end

    it "doesn't perform a lookup when routing number is invalid" do
      expect(ColumnService).not_to receive(:get)

      get :validate_routing_number, params: { value: "not a routing number" }
    end

    it "handles unknown routing numbers" do
      get :validate_routing_number, params: { value: "123456789" }

      expect(response.body).to match(/"valid":false/)
    end

    it "returns bank name" do
      get :validate_routing_number, params: { value: "083000137" }

      expect(response.body).to eq({ valid: true, hint: "Jpmorgan Chase Bank, Na" }.to_json)
    end
  end
end
