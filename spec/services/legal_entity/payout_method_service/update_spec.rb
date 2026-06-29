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

    it "blocks switching to Wise while a report tracking the default is being processed" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      # Legacy report with no snapshot still resolves its method from the default.
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      report.update_columns(legal_entity_payout_method_id: nil)

      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::WiseTransfer",
        details_attrs: valid_wise_attrs
      )

      expect(service.run).to be(false)
      expect(service.error_messages.join(" ")).to match(/wise/i)
      expect(user.reload.default_payout_method.details).to be_a(LegalEntity::PayoutMethod::AchTransfer)
    end

    it "allows switching to Wise when processing reports have their own snapshotted method" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      # Snapshotted at creation, so it keeps ACH regardless of the new default.
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      expect(report.legal_entity_payout_method).to be_present

      service = described_class.new(
        user:,
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
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(true)
      new_pm = user.reload.default_payout_method
      expect(new_pm).not_to eq(old_pm)
      expect(report.reload.legal_entity_payout_method).to eq(new_pm)
    end

    it "only re-points failed reports tied to the method being replaced" do
      other_method = user.personal_legal_entity.payout_methods.create!(
        default: false,
        details: LegalEntity::PayoutMethod::Wire.new(
          account_number: "GB29NWBK60161331926819", bic_code: "NWBKGB2L", recipient_country: 1,
          address_line1: "1 Main St", address_city: "London", address_state: "England",
          address_postal_code: "SW1A 1AA"
        )
      )
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      replaced_default = user.default_payout_method

      # Failed report using the default (will be corrected by this update).
      on_default = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursed)
      # Failed report pinned to a different method (must stay put).
      on_other = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursed)
      on_other.update_columns(legal_entity_payout_method_id: other_method.id)
      [on_default, on_other].each do |report|
        Reimbursement::PayoutHolding.insert_all([{
                                                  reimbursement_reports_id: report.id, amount_cents: 100,
                                                  aasm_state: "failed", created_at: Time.current, updated_at: Time.current
                                                }])
      end

      described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      ).run

      new_default = user.reload.default_payout_method
      expect(new_default).not_to eq(replaced_default)
      expect(on_default.reload.legal_entity_payout_method).to eq(new_default)
      expect(on_other.reload.legal_entity_payout_method).to eq(other_method)
    end

    it "re-points draft reports to the corrected method" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      old_pm = report.legal_entity_payout_method

      service = described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      )

      expect(service.run).to be(true)
      new_pm = user.reload.default_payout_method
      expect(new_pm).not_to eq(old_pm)
      expect(report.reload.legal_entity_payout_method).to eq(new_pm)
    end

    it "only re-points draft reports tied to the method being replaced" do
      other_method = user.personal_legal_entity.payout_methods.create!(
        default: false,
        details: LegalEntity::PayoutMethod::Wire.new(
          account_number: "GB29NWBK60161331926819", bic_code: "NWBKGB2L", recipient_country: 1,
          address_line1: "1 Main St", address_city: "London", address_state: "England",
          address_postal_code: "SW1A 1AA"
        )
      )
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      replaced_default = user.default_payout_method

      # Draft using the default (will be corrected by this update).
      on_default = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      # Draft pinned to a different method (must stay put).
      on_other = create(:reimbursement_report, user:, event: create(:event), aasm_state: :draft)
      on_other.update_columns(legal_entity_payout_method_id: other_method.id)

      described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      ).run

      new_default = user.reload.default_payout_method
      expect(new_default).not_to eq(replaced_default)
      expect(on_default.reload.legal_entity_payout_method).to eq(new_default)
      expect(on_other.reload.legal_entity_payout_method).to eq(other_method)
    end

    it "leaves healthy in-flight reports pinned to their snapshot on update" do
      seed_default(LegalEntity::PayoutMethod::AchTransfer.new(valid_ach_attrs))
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      old_pm = report.legal_entity_payout_method

      described_class.new(
        user:,
        details_type: "LegalEntity::PayoutMethod::AchTransfer",
        details_attrs: valid_ach_attrs
      ).run

      expect(report.reload.legal_entity_payout_method).to eq(old_pm)
    end

    it "blocks any change while a Wise payout tracking the default is being processed" do
      seed_default(LegalEntity::PayoutMethod::WiseTransfer.new(valid_wise_attrs))
      # Legacy report with no snapshot still resolves its method from the default.
      report = create(:reimbursement_report, user:, event: create(:event), aasm_state: :reimbursement_requested)
      report.update_columns(legal_entity_payout_method_id: nil)

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
