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
    before do
      stub_request(:get, /api\.column\.com\/institutions/)
        .to_return(status: 200, body: { country_code: "GB" }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "creates the chosen method as the user's default when none exists" do
      service = described_class.new(
        legal_entity: user.personal_legal_entity,
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
        legal_entity: user.personal_legal_entity,
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
        legal_entity: user.personal_legal_entity,
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
        legal_entity: user.personal_legal_entity,
        details_type: "User",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(false)
      expect(user.reload.default_payout_method).to be_nil
      expect(User).not_to have_received(:new)
    end

    it "surfaces detail validation errors without persisting" do
      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: { account_number: "12345678", routing_number: "nope" }
      )

      expect(service.run).to be(false)
      expect(service.error_messages.join(" ")).to match(/routing number/i)
      expect(user.reload.default_payout_method).to be_nil
    end

    it "allows switching to Wise" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      expect(report.legal_entity_payout_method).to be_present

      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::WiseTransfer",
        details_attrs: valid_wise_attrs
      )

      expect(service.run).to be(true)
      expect(user.reload.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::WiseTransfer)
    end

    it "re-points reports with a failed payout to the corrected method" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursed)
      old_pm = report.legal_entity_payout_method
      Reimbursement::PayoutHolding.insert_all([{
                                                reimbursement_reports_id: report.id, amount_cents: 100,
                                                aasm_state: "failed", created_at: Time.current, updated_at: Time.current
                                              }])

      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs,
        replacing: old_pm
      )

      expect(service.run).to be(true)
      new_pm = user.reload.default_payout_method
      expect(new_pm).not_to eq(old_pm)
      expect(report.reload.legal_entity_payout_method).to eq(new_pm)
    end

    it "re-points draft reports to the corrected method" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      old_pm = report.legal_entity_payout_method

      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs,
        replacing: old_pm
      )

      expect(service.run).to be(true)
      new_pm = user.reload.default_payout_method
      expect(new_pm).not_to eq(old_pm)
      expect(report.reload.legal_entity_payout_method).to eq(new_pm)
    end

    it "leaves healthy in-flight reports pinned to their own payout method on update" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      old_pm = report.legal_entity_payout_method

      described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      ).run

      expect(report.reload.legal_entity_payout_method).to eq(old_pm)
    end
  end

  describe "editing with `replacing:`" do
    before do
      stub_request(:get, /api\.column\.com\/institutions/)
        .to_return(status: 200, body: { country_code: "GB" }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "creates a new record and archives the one being replaced (never mutates or destroys)" do
      old = seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))

      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: { account_number: "99999999", routing_number: "021000021" },
        make_default: old.default?,
        replacing: old
      )

      expect(service.run).to be(true)

      # The old record is archived (kept for audit / report snapshots), not destroyed.
      expect(LegalEntity::PayoutMethod.exists?(old.id)).to be(true)
      expect(old.reload.archived).to be(true)
      expect(old).not_to be_default

      new_pm = user.reload.default_payout_method
      expect(new_pm).not_to eq(old)
      expect(new_pm).not_to be_archived
      expect(new_pm.details.account_number).to eq("99999999")
    end

    it "keeps the new record as default when the replaced one was default" do
      old = seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))

      described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs,
        make_default: old.default?,
        replacing: old
      ).run

      expect(user.personal_legal_entity.payout_methods.where(default: true).count).to eq(1)
      expect(user.reload.default_payout_method).to be_default
    end

    it "repoints a draft report from the replaced method to the new one" do
      old = seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      expect(report.legal_entity_payout_method).to eq(old)

      described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs,
        make_default: old.default?,
        replacing: old
      ).run

      new_pm = user.reload.default_payout_method
      expect(report.reload.legal_entity_payout_method).to eq(new_pm)
    end
  end

  describe "#run!" do
    it "raises ActiveRecord::RecordInvalid when the update is invalid" do
      service = described_class.new(
        legal_entity: user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: { account_number: "12345678", routing_number: "nope" }
      )

      expect { service.run! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
