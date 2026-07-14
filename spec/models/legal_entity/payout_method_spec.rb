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
      expect(payout_method.title_kind).to eq("ACH Transfer")
    end
  end

  describe "#name / #display_name" do
    it "stores a user-provided name" do
      payout_method = legal_entity.payout_methods.create!(details: build_ach, name: "My Chase Bank Account")

      expect(payout_method.name).to eq("My Chase Bank Account")
      expect(payout_method.display_name).to eq("My Chase Bank Account")
    end

    it "falls back to the method type when unnamed" do
      payout_method = legal_entity.payout_methods.create!(details: build_ach)

      expect(payout_method.name).to be_nil
      expect(payout_method.display_name).to eq("ACH Transfer")
    end

    it "rejects names longer than 100 characters" do
      payout_method = legal_entity.payout_methods.new(details: build_ach, name: "a" * 101)

      expect(payout_method).not_to be_valid
      expect(payout_method.errors[:name]).to be_present
    end
  end

  describe "#create_transfer (key remapping / consolidation)" do
    let(:event) { create(:event) }
    let(:user)  { create(:user) }

    let(:attrs) do
      {
        amount: 10_000,
        memo: "m" * 60,
        payment_for: "p" * 200,
        recipient_name: "Jane Doe",
        recipient_email: "jane@example.com",
        currency: "USD",
        user:,
      }
    end

    context "Wire" do
      let(:details) { build(:wire_payout_method_details, recipient_information: {}) }

      it "maps :amount to :amount_cents and caps :payment_for at 140, keeping :memo/:user" do
        wire = details.create_transfer(event, **attrs)

        expect(wire).to be_a(Wire)
        expect(wire.amount_cents).to eq(10_000)
        expect(wire.payment_for.length).to eq(140)
        expect(wire.memo).to eq("m" * 60)
        expect(wire.user).to eq(user)
        expect(wire.recipient_name).to eq("Jane Doe")
      end
    end

    context "WiseTransfer" do
      let(:details) { build(:wise_transfer_payout_method_details, currency: "GBP") }

      it "maps :amount to :amount_cents and drops :memo/:currency (uses its own currency)" do
        wise = details.create_transfer(event, **attrs)

        expect(wise).to be_a(WiseTransfer)
        expect(wise.amount_cents).to eq(10_000)
        expect(wise.currency).to eq("GBP")
        expect(wise.user).to eq(user)
      end
    end

    context "AchTransfer" do
      let(:details) { build(:ach_transfer_payout_method_details) }

      before { allow(ColumnService).to receive(:get).and_return("full_name" => "Test Bank") }

      it "maps :user to :creator, derives :bank_name, drops :memo, and has no currency" do
        ach = details.create_transfer(event, **attrs)

        expect(ach).to be_a(AchTransfer)
        expect(ach.creator).to eq(user)
        expect(ach.bank_name).to eq("Test Bank")
        expect(ach.amount).to eq(10_000) # USD passthrough
        expect(ach.routing_number).to eq("021000021")
      end

      it "ignores :currency and passes the amount through (ACH is USD-only)" do
        ach = details.create_transfer(event, **attrs.merge(currency: "EUR"))

        expect(ach.amount).to eq(10_000)
      end
    end

    context "Check" do
      let(:details) { build(:check_payout_method_details) }

      it "truncates :memo to 40 chars and drops :currency" do
        check = details.create_transfer(event, **attrs)

        expect(check).to be_a(IncreaseCheck)
        expect(check.memo.length).to eq(40)
        expect(check.amount).to eq(10_000) # USD passthrough
        expect(check.user).to eq(user)
        expect(check.recipient_name).to eq("Jane Doe")
      end
    end

    it "does not error when a method-irrelevant key is omitted" do
      ach_details = build(:ach_transfer_payout_method_details)
      allow(ColumnService).to receive(:get).and_return("full_name" => "Test Bank")

      expect {
        ach_details.create_transfer(event, amount: 500, payment_for: "x", recipient_name: "A", recipient_email: "a@b.co", user:)
      }.not_to raise_error
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

  describe "#locked_by_processing_reimbursement_report?" do
    let(:user) { create(:user) }

    def method_with_report_in(state)
      pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: state, legal_entity_payout_method: pm)
      pm
    end

    it "is locked while a report using it is in-flight" do
      %i[submitted reimbursement_requested reimbursement_approved].each do |state|
        expect(method_with_report_in(state).locked_by_processing_reimbursement_report?).to be(true), "expected locked for #{state}"
      end
    end

    it "is unlocked while the report is a draft or finished" do
      %i[draft reimbursed rejected reversed].each do |state|
        expect(method_with_report_in(state).locked_by_processing_reimbursement_report?).to be(false), "expected unlocked for #{state}"
      end
    end

    it "is unlocked when no report uses it" do
      pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)
      expect(pm.locked_by_processing_reimbursement_report?).to be(false)
    end
  end

  describe "#locked_reimbursement_reports" do
    let(:user) { create(:user) }
    let(:pm) { user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach) }

    def report_in(state)
      create(:reimbursement_report, user:, event: create(:event), aasm_state: state, legal_entity_payout_method: pm)
    end

    it "returns only the in-flight reports using the method" do
      locking = %i[submitted reimbursement_requested reimbursement_approved].map { |s| report_in(s) }
      %i[draft reimbursed rejected reversed].each { |s| report_in(s) }

      expect(pm.locked_reimbursement_reports).to match_array(locking)
    end
  end
end
