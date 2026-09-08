# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  def build_ach
    LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
  end

  describe "validations" do
    context "when backed by a card grant" do
      # The card_grant factory's after_create :transfer_money callback runs
      # DisbursementService::Create, which requires a funded source event.
      # These specs only care about the card_grant FK, not real disbursement
      # mechanics, so we stub the callback the same way spec/models/card_grant_spec.rb does.
      before do
        allow_any_instance_of(CardGrant).to receive(:transfer_money)
      end

      it "rejects event_id changes" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:)

        report.event = destination_event

        expect(report.valid?(:update)).to be(false)
        expect(report.errors[:base]).to include(/card grant/i)
      end

      it "permits updates that do not change the event" do
        source_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:, name: "Old Name")

        report.name = "New Name"

        expect(report.valid?(:update)).to be(true)
      end
    end

    context "when not backed by a card grant" do
      it "permits event_id changes at the model layer" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        report = create(:reimbursement_report, user:, event: source_event)

        report.event = destination_event

        expect(report.valid?(:update)).to be(true)
      end
    end
  end

  describe "payout method association" do
    let(:user) { create(:user) }

    describe "setting the payout method on create" do
      it "sets the user's default payout method on the report" do
        pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to eq(pm)
        expect(report.payout_method).to eq(pm)
      end

      it "leaves the column null when the user has no default" do
        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to be_nil
      end

      it "does not overwrite an explicitly-assigned payout method" do
        default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        other_pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)

        report = create(:reimbursement_report, user:, legal_entity_payout_method: other_pm)

        expect(report.legal_entity_payout_method).to eq(other_pm)
        expect(report.legal_entity_payout_method).not_to eq(default_pm)
      end
    end

    describe "#payout_method" do
      it "returns the method set on the report even after the user's default changes" do
        original_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        report = create(:reimbursement_report, user:)

        user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        expect(report.reload.payout_method).to eq(original_pm)
      end
    end
  end

  describe "#committed_amount_cents" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    def report_with_expense(aasm_state, cents, maximum_amount_cents: nil, expense_state: :approved)
      report = create(:reimbursement_report, user:, event:, aasm_state:, maximum_amount_cents:)
      create(:reimbursement_expense, report:, value: cents / 100.0, aasm_state: expense_state) if cents.positive?
      report
    end

    context "when the report is a draft with a maximum" do
      it "reports the maximum even though nothing has been filed" do
        report = report_with_expense(:draft, 0, maximum_amount_cents: 50_000)

        expect(report.amount_cents).to eq(0)
        expect(report.committed_amount_cents).to eq(50_000)
      end

      it "reports the maximum rather than the expenses filed under it" do
        report = report_with_expense(:draft, 8_000, maximum_amount_cents: 50_000, expense_state: :pending)

        expect(report.committed_amount_cents).to eq(50_000)
      end

      # `submit` is guarded on `!exceeds_maximum_amount?`, so an over-maximum
      # report is a state reports sit in rather than pass through.
      it "reports the maximum rather than expenses filed above it" do
        report = report_with_expense(:draft, 70_000, maximum_amount_cents: 50_000, expense_state: :pending)

        expect(report.amount_cents).to eq(70_000)
        expect(report.committed_amount_cents).to eq(50_000)
      end

      it "leaves `exceeds_maximum_amount?` reading the filed expenses" do
        report = report_with_expense(:draft, 70_000, maximum_amount_cents: 50_000, expense_state: :pending)

        expect(report).to be_exceeds_maximum_amount
      end

      # `exceeds_maximum_amount?` skips non-USD reports, but ops check the Wise
      # total against the maximum before approving the transfer, so it binds
      # here too. `maximum_amount_cents` is denominated in USD.
      it "reports the maximum on a non-USD report" do
        report = report_with_expense(:draft, 8_000, maximum_amount_cents: 50_000, expense_state: :pending)
        report.update!(currency: "EUR")

        expect(report.committed_amount_cents).to eq(50_000)
      end
    end

    context "when the report has no maximum" do
      it "matches the expenses filed on a draft" do
        report = report_with_expense(:draft, 8_000, expense_state: :pending)

        expect(report.committed_amount_cents).to eq(report.amount_cents)
        expect(report.committed_amount_cents).to eq(8_000)
      end
    end

    context "when the report is past draft" do
      it "matches `amount_cents` once submitted, maximum or not" do
        report = report_with_expense(:submitted, 5_000, maximum_amount_cents: 50_000, expense_state: :pending)

        expect(report.committed_amount_cents).to eq(5_000)
      end

      it "matches `amount_cents` once reimbursement has been requested" do
        report = report_with_expense(:reimbursement_requested, 10_000, maximum_amount_cents: 50_000)

        expect(report.committed_amount_cents).to eq(10_000)
      end
    end
  end
end
