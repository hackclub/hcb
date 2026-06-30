# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethod, type: :model do
  let(:legal_entity) { create(:legal_entity) }

  def build_ach
    LegalEntity::PayoutMethod::AchTransfer.create!(account_number: "12345678", routing_number: "021000021")
  end

  def build_check
    LegalEntity::PayoutMethod::Check.create!(
      address_line1: "1 Main St",
      address_city: "New York",
      address_state: "NY",
      address_postal_code: "10001"
    )
  end

  describe "associations" do
    it "belongs to a legal entity" do
      payout_method = legal_entity.payout_methods.create!(details: build_ach)
      expect(payout_method.legal_entity).to eq(legal_entity)
    end

    it "belongs to a polymorphic details record" do
      ach = build_ach
      payout_method = legal_entity.payout_methods.create!(details: ach)
      expect(payout_method.details).to eq(ach)
      expect(payout_method.details_type).to eq("LegalEntity::PayoutMethod::AchTransfer")
    end

    it "requires details" do
      payout_method = LegalEntity::PayoutMethod.new(legal_entity:)
      expect(payout_method).not_to be_valid
      expect(payout_method.errors[:details]).to be_present
    end

    it "destroys its details record when destroyed" do
      ach = build_ach
      payout_method = legal_entity.payout_methods.create!(details: ach)

      expect { payout_method.destroy! }
        .to change { LegalEntity::PayoutMethod::AchTransfer.exists?(ach.id) }.from(true).to(false)
    end
  end

  describe "multiple payout methods of multiple types" do
    it "allows a legal entity to hold several methods of different types" do
      legal_entity.payout_methods.create!(details: build_ach)
      legal_entity.payout_methods.create!(details: build_check)

      types = legal_entity.payout_methods.map { |pm| pm.details.class.name.demodulize }
      expect(types).to contain_exactly("AchTransfer", "Check")
    end
  end

  describe "default handling" do
    it "keeps at most one default per legal entity" do
      first = legal_entity.payout_methods.create!(details: build_ach, default: true)
      second = legal_entity.payout_methods.create!(details: build_check, default: true)

      expect(second.reload).to be_default
      expect(first.reload).not_to be_default
      expect(legal_entity.payout_methods.where(default: true).count).to eq(1)
    end

    it "does not unset defaults belonging to other legal entities" do
      other_entity = create(:legal_entity)
      other_default = other_entity.payout_methods.create!(details: build_ach, default: true)

      legal_entity.payout_methods.create!(details: build_check, default: true)

      expect(other_default.reload).to be_default
    end
  end

  describe "delegation to details" do
    it "delegates presentation methods to the details record" do
      payout_method = legal_entity.payout_methods.create!(details: build_ach)

      expect(payout_method.kind).to eq("ach_transfer")
      expect(payout_method.currency).to eq("USD")
      expect(payout_method.name).to eq("an ACH transfer")
    end
  end

  describe "supported / unsupported methods" do
    it "is supported when its type is not in UNSUPPORTED_METHODS" do
      payout_method = legal_entity.payout_methods.create!(details: build_ach)
      expect(payout_method).not_to be_unsupported
    end

    context "when the details type is unsupported" do
      before do
        stub_const(
          "LegalEntity::PayoutMethod::UNSUPPORTED_METHODS",
          { LegalEntity::PayoutMethod::Check => { status_badge: "Unavailable", reason: "Checks are paused." } }
        )
      end

      it "reports unsupported details" do
        payout_method = LegalEntity::PayoutMethod.new(legal_entity:, details: build_check)
        expect(payout_method).to be_unsupported
        expect(payout_method.unsupported_details[:reason]).to eq("Checks are paused.")
      end

      it "is invalid" do
        payout_method = LegalEntity::PayoutMethod.new(legal_entity:, details: build_check)
        expect(payout_method).not_to be_valid
        expect(payout_method.errors[:base].join).to include("Checks are paused.")
      end
    end
  end

  describe "#locked_by_processing_report?" do
    let(:user) { create(:user) }

    def method_with_report_in(state)
      pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: state, legal_entity_payout_method: pm)
      pm
    end

    it "is locked while a report using it is in-flight" do
      %i[submitted reimbursement_requested reimbursement_approved].each do |state|
        expect(method_with_report_in(state).locked_by_processing_report?).to be(true), "expected locked for #{state}"
      end
    end

    it "is unlocked while the report is a draft or finished" do
      %i[draft reimbursed rejected reversed].each do |state|
        expect(method_with_report_in(state).locked_by_processing_report?).to be(false), "expected unlocked for #{state}"
      end
    end

    it "is unlocked when no report uses it" do
      pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)
      expect(pm.locked_by_processing_report?).to be(false)
    end
  end
end
