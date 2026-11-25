# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethod::WiseTransfer, type: :model do
  let(:event) { create(:event) }

  subject(:payout_method) do
    build(:wise_transfer_payout_method_details, currency: "AED")
  end

  describe "required recipient fields" do
    it "requires a date of birth on create" do
      details = build(:wise_transfer_payout_method_details, recipient_birthday: nil)
      expect(details).not_to be_valid
      expect(details.errors[:recipient_birthday]).to include("can't be blank")
    end

    it "rejects a malformed date of birth" do
      details = build(:wise_transfer_payout_method_details, recipient_birthday: "13/45/1990")
      expect(details).not_to be_valid
      expect(details.errors[:recipient_birthday].join).to include("MM/DD/YYYY")
    end

    it "accepts the ISO dates older KRW and ZAR records were saved with" do
      details = build(:wise_transfer_payout_method_details, recipient_birthday: "1990-01-15")
      expect(details).to be_valid
    end

    it "rejects a date of birth in the future" do
      details = build(:wise_transfer_payout_method_details, recipient_birthday: 1.year.from_now.strftime("%m/%d/%Y"))
      expect(details).not_to be_valid
      expect(details.errors[:recipient_birthday]).to include("can't be in the future")
    end

    it "keeps existing records without a date of birth saveable and reports the missing field" do
      details = create(:wise_transfer_payout_method_details)
      details.update!(recipient_birthday: nil)
      details.reload

      expect(details.recipient_birthday).to be_blank
      expect(details.missing_required_fields).to eq(["recipient_birthday"])
      expect(details.update(bank_name: "Monzo")).to be(true)
    end
  end

  describe "#create_transfer" do
    # $332 in a payment must be paid out as its AED-equivalent, not 332 AED.
    it "converts the USD payment amount into the recipient's local currency" do
      allow(MoneyService).to receive(:convert_from_usd_wise).with(332_00, "AED").and_return(1_218_44)

      transfer = payout_method.create_transfer(
        event,
        amount: 332_00,
        payment_for: "Payment for \"Engineering hours\".",
        recipient_name: "Jane Doe",
        recipient_email: "jane@example.com",
        currency: "USD",
        user: create(:user)
      )

      expect(transfer.currency).to eq("AED")
      expect(transfer.amount_cents).to eq(1_218_44)
    end
  end

  describe "unsupported currencies" do
    let(:legal_entity) { create(:legal_entity) }

    it "can't be created in CNY" do
      details = build(:wise_transfer_payout_method_details, currency: "CNY", account_type: "alipay")
      payout_method = LegalEntity::PayoutMethod.new(legal_entity:, details:)

      expect(payout_method).not_to be_valid
      expect(payout_method.error_messages).to include("Wise transfers in CNY are currently not supported. Please send an international wire instead.")
    end

    it "flags an existing CNY payout method as unavailable" do
      details = create(:wise_transfer_payout_method_details, currency: "CNY", account_type: "alipay", allow_unsupported_recipient: true)
      payout_method = legal_entity.payout_methods.create!(details:)
      payout_method = LegalEntity::PayoutMethod.find(payout_method.id)

      expect(payout_method).to be_valid
      expect(payout_method).to be_unsupported
      expect(payout_method.unsupported_details).to eq(
        status_badge: "Unavailable",
        reason: "Wise transfers in CNY are currently not supported. Please send an international wire instead."
      )
    end
  end
end
