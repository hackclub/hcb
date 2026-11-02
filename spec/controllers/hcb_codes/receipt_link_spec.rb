# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController, type: :controller do
  describe "GET #receipt_link" do
    let(:event) { create(:event) }
    let(:hcb_code) { create(:canonical_pending_transaction, event:, amount_cents: -1_00).local_hcb_code }

    def get_with_token(token, id: hcb_code.hashid)
      get :receipt_link, params: { id:, token: }
    end

    it "routes the token exactly as generated, dot included" do
      route = Rails.application.routes.recognize_path(
        Rails.application.routes.url_helpers.short_receipt_link_path(
          hcb_code.hashid, HcbCodeHelper.receipt_link_token(hcb_code)
        )
      )

      expect(route).to include(controller: "hcb_codes", action: "receipt_link", id: hcb_code.hashid)
      expect(route[:token]).to include(".")
      expect(route[:format]).to be_nil
    end

    it "redirects to the attach receipt page" do
      get_with_token(HcbCodeHelper.receipt_link_token(hcb_code))

      expect(response).to redirect_to(/\Ahttp:\/\/test.host\/hcb\/#{hcb_code.hashid}\/attach_receipt\?s=\S+\z/)
    end

    it "redirects to a page the attach receipt action accepts while signed out" do
      get_with_token(HcbCodeHelper.receipt_link_token(hcb_code))

      location = URI.parse(response.location)
      get :attach_receipt, params: { id: hcb_code.hashid, s: Rack::Utils.parse_query(location.query)["s"] }

      expect(response).to be_successful
    end

    it "rejects a tampered token" do
      token = HcbCodeHelper.receipt_link_token(hcb_code)

      expect { get_with_token(token.reverse) }.to raise_error(ActionController::RoutingError)
    end

    it "rejects a token whose payload was edited" do
      expiry, signature = HcbCodeHelper.receipt_link_token(hcb_code, expires_at: 1.week.from_now).split(".")

      expect {
        get_with_token("#{(Time.now.to_i + 2.weeks.to_i).to_s(36)}.#{signature}")
      }.to raise_error(ActionController::RoutingError)

      expect { get_with_token("#{expiry}.#{"0" * 32}") }.to raise_error(ActionController::RoutingError)
    end

    it "rejects an expired token" do
      expect {
        get_with_token(HcbCodeHelper.receipt_link_token(hcb_code, expires_at: 1.second.ago))
      }.to raise_error(ActionController::RoutingError)
    end

    it "rejects a token for a different hcb code" do
      other = create(:canonical_pending_transaction, event:, amount_cents: -2_00).local_hcb_code

      expect {
        get_with_token(HcbCodeHelper.receipt_link_token(other))
      }.to raise_error(ActionController::RoutingError)
    end

    it "rejects a malformed token" do
      expect { get_with_token("garbage") }.to raise_error(ActionController::RoutingError)
    end

    it "rejects an unknown hcb code" do
      expect {
        get_with_token(HcbCodeHelper.receipt_link_token(hcb_code), id: "HCB-UNKNOWN")
      }.to raise_error(ActionController::RoutingError)
    end
  end
end
