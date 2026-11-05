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

  describe ".search" do
    let!(:report) do
      user = create(:user, full_name: "Orpheus Dinosaur", email: "orpheus@hackclub.com")
      create(:reimbursement_report, user:, name: "Sticker printing")
    end

    it "matches on the reimbursee's email" do
      expect(described_class.search("orpheus@hackclub.com")).to eq([report])
      expect(described_class.search("@hackclub.com")).to eq([report])
    end

    it "matches on the reimbursee's full name" do
      expect(described_class.search("dinosaur")).to eq([report])
    end

    it "matches on the report name" do
      expect(described_class.search("sticker")).to eq([report])
    end

    it "returns nothing when there's no match" do
      expect(described_class.search("nobody@example.com")).to be_empty
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

  describe "submitting" do
    let(:user) { create(:user) }
    let(:report) do
      user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
      create(:reimbursement_report, user:)
    end

    def add_expense(**attributes)
      expense = report.expenses.create!(value: 12.34, memo: "Stickers", **attributes)
      ReceiptService::Create.new(
        receiptable: expense,
        uploader: user,
        attachments: [file_fixture("receipt.png")],
        upload_method: :receipts_page
      ).run!
      expense
    end

    it "requires every expense to have a category" do
      add_expense(category: "Project Supplies")
      uncategorized = add_expense

      expect(report.missing_categories?).to be(true)
      expect(report.may_mark_submitted?).to be(false)

      uncategorized.update!(category: "Prizes")

      expect(report.missing_categories?).to be(false)
      expect(report.may_mark_submitted?).to be(true)
    end

    it "does not require a category on fees" do
      add_expense(category: "Project Supplies")
      report.expenses.create!(value: 1, memo: "Wise fee", type: Reimbursement::Expense::Fee.name)

      expect(report.missing_categories?).to be(false)
    end
  end

  describe "with an incomplete payout method" do
    let(:user) { create(:user) }
    let(:payout_method) do
      user.personal_legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details)).tap do |pm|
        pm.details.update!(recipient_birthday: nil)
        pm.details.reload
      end
    end

    it "is not allowed for submission" do
      report = create(:reimbursement_report, user:, legal_entity_payout_method: payout_method)
      expect(report.payout_method_incomplete?).to be(true)
      expect(report.send(:payout_method_allowed?)).to be(false)
    end

    it "holds HCB approval of an in-flight report" do
      report = create(:reimbursement_report, user:, legal_entity_payout_method: payout_method, aasm_state: :reimbursement_requested, currency: "GBP")
      allow(report).to receive(:expenses).and_return(double(approved: double(exists?: true, sum: 100_00)))
      allow(report).to receive(:amount_to_reimburse).and_return(Money.from_cents(100_00, "GBP"))

      expect(report.may_mark_reimbursement_approved?).to be(false)

      payout_method.complete_details!({ "recipient_birthday" => "01/15/1990" })
      report.payout_method.details.reload
      expect(report.may_mark_reimbursement_approved?).to be(true)
    end

    it "refuses to convert to a Wise transfer" do
      report = create(:reimbursement_report, user:, legal_entity_payout_method: payout_method, aasm_state: :reimbursement_requested)
      expect { report.convert_to_wise_transfer!(as: user) }.to raise_error(RuntimeError, /date of birth/)
    end
  end

  describe "the invitation email" do
    it "is sent when somebody else invited the user" do
      inviter = create(:user)

      expect {
        create(:reimbursement_report, user: create(:user), inviter:)
      }.to have_enqueued_mail(ReimbursementMailer, :invitation)
    end

    it "is not sent when the user created the report themselves" do
      user = create(:user)

      expect {
        create(:reimbursement_report, user:, inviter: user)
      }.not_to have_enqueued_mail(ReimbursementMailer, :invitation)
    end

    # Eventless draft reports come in from Discord, SMS, and email, and the
    # invitation email is event-scoped from its subject line down. Enqueuing it
    # for one raised NoMethodError on nil in the mail delivery job.
    it "is not sent for an eventless draft report" do
      expect {
        create(:reimbursement_report, user: create(:user), event: nil, inviter: nil)
      }.not_to have_enqueued_mail(ReimbursementMailer, :invitation)
    end
  end
end
