# frozen_string_literal: true

require "rails_helper"

describe AchTransfersController do
  include SessionSupport

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
      user = create(:user)
      sign_in(user)
    end

    context "when value param is empty" do
      it "doesn't perform a lookup and is valid" do
        get :validate_routing_number, params: { value: "" }

        body = JSON.parse(response.body)
        expect(ColumnService).not_to receive(:get)
        expect(body["valid"]).to be_truthy
      end
    end

    context "when value param is in invalid format" do
      it "is invalid" do
        get :validate_routing_number, params: { value: "INVALID_FORMAT" }

        body = JSON.parse(response.body)

        expect(ColumnService).not_to receive(:get)
        expect(body["valid"]).to be_falsy
        expect(body["hint"]).to eq "Bank not found for this routing number."
      end
    end

    context "when using ColumnService to get instructions" do
      let(:param_value) { "123456789" }
      context "when routing number type is different than aba" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { routing_number_type: "not_aba" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_falsy
          expect(body["hint"]).to eq "Please enter an ABA routing number."
        end
      end

      context "when ach_eligible is false and routing_number_type is 'aba'" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { ach_eligible: false, routing_number_type: "aba" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_falsy
          expect(body["hint"]).to eq "This routing number cannot accept ACH transfers."
        end
      end

      context "when ach_eligible is true and routing_number_type is 'aba'" do
        it "is invalid" do
          stub_request(:get, "https://api.column.com/institutions/#{param_value}")
            .to_return_json(status: 200, body: { ach_eligible: true, routing_number_type: "aba", full_name: "full name" })

          get :validate_routing_number, params: { value: param_value }
          body = JSON.parse(response.body)

          expect(body["valid"]).to be_truthy
          expect(body["hint"]).to eq "Full Name"
        end
      end
    end
  end
end
