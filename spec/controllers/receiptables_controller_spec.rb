# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptablesController do
  include SessionSupport

  describe "#mark_no_or_lost" do
    let(:cpt) { create(:canonical_pending_transaction) }
    let(:hcb_code) { cpt.local_hcb_code }
    let(:base_params) { { receiptable_type: "HcbCode", receiptable_id: hcb_code.id } }

    it "marks the transaction using the secret from a receipt request email, without signing in" do
      secret = hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)

      post(:mark_no_or_lost, params: base_params.merge(s: secret), as: :html)

      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(flash[:success]).to eq("Marked no/lost receipt on that transaction.")
      expect(URI.parse(response.location).path)
        .to eq(attach_receipt_hcb_code_path(id: hcb_code.hashid))
    end

    it "refuses a signed out user without a valid secret" do
      post(:mark_no_or_lost, params: base_params.merge(s: "not-a-real-secret"), as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "marks the transaction and returns to it when signed in" do
      user = create(:user, :make_admin)
      create_session(user, verified: true)

      post(:mark_no_or_lost, params: base_params, as: :html)

      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(response).to redirect_to(hcb_code_path(hcb_code))
    end
  end

  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!

      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        expect(ReceiptablesController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end
end
