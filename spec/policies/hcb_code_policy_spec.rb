# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodePolicy, type: :policy do
  describe "#user_made_purchase?" do
    let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }

    context "when the charge's cardholder can't be resolved" do
      before do
        allow(hcb_code).to receive_messages(stripe_card?: true, stripe_cardholder: nil)
      end

      it "does not treat a signed out visitor as the purchaser" do
        expect(described_class.new(nil, hcb_code).user_made_purchase?).to be(false)
      end

      it "does not authorize a signed out visitor to attach a receipt" do
        expect(described_class.new(nil, hcb_code).attach_receipt?).to be_falsey
      end

      it "does not authorize a signed out visitor through ReceiptablePolicy" do
        expect(ReceiptablePolicy.new(nil, hcb_code).mark_no_or_lost?).to be_falsey
      end

      it "does not treat an unrelated signed in user as the purchaser" do
        expect(described_class.new(create(:user), hcb_code).user_made_purchase?).to be(false)
      end
    end

    it "treats the cardholder's own user as the purchaser" do
      cardholder = create(:stripe_cardholder)
      allow(hcb_code).to receive_messages(stripe_card?: true, stripe_cardholder: cardholder)

      expect(described_class.new(cardholder.user, hcb_code).user_made_purchase?).to be(true)
    end
  end
end
