# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethodService::Update do
  let(:user) { create(:user) }

  def valid_ach_attrs
    { account_number: "12345678", routing_number: "021000021" }
  end

  def valid_wise_attrs
    {
      address_line1: "1 Main St", address_city: "Toronto", address_state: "ON",
      address_postal_code: "M5V2T6", recipient_country: "CA", currency: "CAD"
    }
  end

  def seed_default(details)
    user.personal_legal_entity.payout_methods.create!(default: true, details:)
  end

  describe "#run" do
    it "creates the chosen method as the user's default when none exists" do
      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(true)

      default = user.reload.default_payout_method
      expect(default).to be_present
      expect(default).to be_default
      expect(default.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
      expect(default.details.routing_number).to eq("021000021")
    end

    it "replaces the existing default and unsets the previous one" do
      old = seed_default(LegalEntity::PayoutMethod::Check.new(
                           address_line1: "1 Main St", address_city: "New York",
                           address_state: "NY", address_postal_code: "10001"
                         ))

      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(true)
      expect(user.personal_legal_entity.payout_methods.where(default: true).count).to eq(1)
      expect(user.reload.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
      expect(old.reload).not_to be_default
    end

    it "fails without persisting when the type is not a supported payout method" do
      service = described_class.new(
        user:,
        details_type: "User::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(false)
      expect(service.error_messages).to be_present
      expect(user.reload.default_payout_method).to be_nil
    end

    it "does not instantiate an arbitrary class named by the type" do
      # Guards against code injection: a real but non-allowlisted class must be
      # rejected by name without being resolved or instantiated.
      user # create before spying (FactoryBot legitimately calls User.new)
      allow(User).to receive(:new).and_call_original

      service = described_class.new(
        user:,
        details_type: "User",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(false)
      expect(user.reload.default_payout_method).to be_nil
      expect(User).not_to have_received(:new)
    end

    it "surfaces detail validation errors without persisting" do
      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: { account_number: "12345678", routing_number: "nope" }
      )

      expect(service.run).to be(false)
      expect(service.error_messages.join(" ")).to match(/routing number/i)
      expect(user.reload.default_payout_method).to be_nil
    end

    it "blocks switching to Wise while a report is being processed" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)

      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::WiseTransfer",
        details_attrs: valid_wise_attrs
      )

      expect(service.run).to be(false)
      expect(service.error_messages.join(" ")).to match(/wise/i)
      expect(user.reload.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
    end

    it "blocks any change while the current Wise payout is being processed" do
      seed_default(LegalEntity::PayoutMethod::WiseTransfer.new(valid_wise_attrs))
      create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)

      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(false)
      expect(user.reload.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::WiseTransfer)
    end
  end

  describe "#run!" do
    it "raises ActiveRecord::RecordInvalid when the update is invalid" do
      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: { account_number: "12345678", routing_number: "nope" }
      )

      expect { service.run! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
