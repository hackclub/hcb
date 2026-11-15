# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawColumnTransaction, type: :model do
  describe "#canonize" do
    let(:event) { create(:event, :with_positive_balance) }

    let!(:check) do
      IncreaseCheck.create!(
        event:,
        amount: 10_00,
        memo: "Venue deposit",
        payment_for: "Venue deposit",
        recipient_name: "Recipient",
        recipient_email: "recipient@example.com",
        address_line1: "1 Main St",
        address_city: "City",
        address_state: "CA",
        address_zip: "94000"
      )
    end
    let(:cpt) { check.canonical_pending_transaction }

    before do
      allow(ColumnService).to receive(:get).with("/transfers/book/book_settle_spec")
                                           .and_return({ "description" => "HCB-#{check.local_hcb_code.short_code} Check" })
    end

    def import!
      described_class.create!(
        column_report_id: "rpt_settle_spec",
        transaction_index: 0,
        amount_cents: -10_00,
        date_posted: Date.current,
        column_transaction: { "transaction_id" => "book_settle_spec", "transaction_type" => "book.outgoing_transfer" }
      )
    end

    it "creates the canonical transaction and settles its pending transaction together" do
      expect(cpt).to be_unsettled
      ledger_item = cpt.ledger_item
      amounts = []
      allow_any_instance_of(Ledger::Item).to receive(:refresh!).and_wrap_original do |m, *args|
        m.call(*args).tap { amounts << m.receiver.amount_cents if m.receiver.id == ledger_item.id }
      end

      raw = import!

      ct = raw.canonical_transaction
      expect(ct.hcb_code).to eq(check.hcb_code)
      expect(ct.canonical_pending_transaction).to eq(cpt)
      expect(cpt.reload).to be_settled
      expect(ledger_item.reload.amount_cents).to eq(-10_00)
      expect(amounts).not_to be_empty
      expect(amounts).to all(eq(-10_00))
    end

    it "rolls the canonical transaction back when settling fails" do
      allow_any_instance_of(CanonicalPendingTransactionService::Settle).to receive(:run!).and_raise("settle failed")

      expect { import! }.to raise_error("settle failed")

      expect(described_class.find_by(column_report_id: "rpt_settle_spec")).to be_nil
      expect(CanonicalTransaction.where(transaction_source_type: "RawColumnTransaction").count).to eq(0)
      expect(cpt.reload).to be_unsettled
    end
  end
end
