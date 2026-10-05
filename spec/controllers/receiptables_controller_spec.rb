# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptablesController do
  include SessionSupport

  describe "#mark_no_or_lost" do
    let(:event) { create(:event) }
    let(:cpt) { create(:canonical_pending_transaction) }
    let(:hcb_code) { cpt.local_hcb_code }
    let(:base_params) { { receiptable_type: "HcbCode", receiptable_id: hcb_code.id } }
    let(:secret) { hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload) }

    before { create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:) }

    it "marks the transaction using the secret from a receipt request email, without signing in" do
      post(:mark_no_or_lost, params: base_params.merge(s: secret), as: :html)

      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(flash[:success]).to eq("Marked no/lost receipt on that transaction.")
      expect(response).to redirect_to(attach_receipt_hcb_code_path(hcb_code, s: secret))
    end

    it "refuses a secret issued for a different transaction" do
      other_hcb_code = create(:canonical_pending_transaction).local_hcb_code
      other_secret = other_hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)

      post(:mark_no_or_lost, params: base_params.merge(s: other_secret), as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(other_hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a secret issued for a different purpose" do
      status_secret = hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_status)

      post(:mark_no_or_lost, params: base_params.merge(s: status_secret), as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses an expired secret" do
      # Mint the secret now, so that travelling past its two week expiry is what
      # invalidates it.
      params_with_secret = base_params.merge(s: secret)

      travel_to 3.weeks.from_now do
        post(:mark_no_or_lost, params: params_with_secret, as: :html)
      end

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a signed out user on a charge whose cardholder doesn't resolve" do
      allow(HcbCode).to receive(:find).and_return(hcb_code)
      allow(hcb_code).to receive_messages(stripe_card?: true, stripe_cardholder: nil)

      post(:mark_no_or_lost, params: base_params, as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "refuses a signed out user without a valid secret" do
      post(:mark_no_or_lost, params: base_params.merge(s: "not-a-real-secret"), as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
    end

    it "marks the transaction and returns to it when signed in as an organizer" do
      user = create(:user)
      create(:organizer_position, user:, event:)
      create_session(user, verified: true)

      post(:mark_no_or_lost, params: base_params, as: :html)

      expect(hcb_code.reload).to be_no_or_lost_receipt
      expect(response).to redirect_to(hcb_code_path(hcb_code))
    end

    it "refuses a signed in user who isn't on the organization" do
      create_session(create(:user), verified: true)

      post(:mark_no_or_lost, params: base_params, as: :html)

      expect(hcb_code.reload).not_to be_no_or_lost_receipt
      expect(flash[:error]).to eq("You are not authorized to perform this action.")
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
