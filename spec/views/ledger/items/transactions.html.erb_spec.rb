# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_transactions" do
  let(:ledger_item) { create(:ledger_item) }

  before do
    # `admin_tool` checks the signed-in user; render as a signed-out visitor.
    def view.current_user = nil
  end

  # The list as a reader sees it, e.g.
  # "Created Jan 10, 2026 $10.00 Lunch ↳ Settled Jan 11, 2026 $10.00 Lunch"
  def render_transactions
    render partial: "ledger/items/transactions", locals: { ledger_item: }
    Nokogiri::HTML(rendered).text.squish
  end

  def labels(text)
    text.scan(/\b(Created|Settled|Updated|Declined)\b/).flatten
  end

  def date(time)
    time.strftime("%b %e, %Y").squish
  end

  def create_card_authorization(stripe_reason: nil, hcb_reason: nil)
    raw = create(:raw_pending_stripe_transaction)
    stripe_transaction = raw.stripe_transaction
    stripe_transaction = stripe_transaction.merge("request_history" => [{ "reason" => stripe_reason }]) if stripe_reason
    stripe_transaction = stripe_transaction.merge("metadata" => { "declined_reason" => hcb_reason }) if hcb_reason
    raw.update!(stripe_transaction:)
    raw
  end

  describe "a declined pending transaction" do
    it "renders the decline as its own row under the pending transaction" do
      raw = create_card_authorization(stripe_reason: "card_expired")
      cpt = create(:canonical_pending_transaction, ledger_item:, memo: "Lunch", raw_pending_stripe_transaction: raw)
      cpt.decline!

      text = render_transactions

      expect(text).to include("Created #{date(cpt.date)} #{cpt.amount.format} Lunch ↳ Declined #{date(cpt.canonical_pending_declined_mapping.created_at)} Card expired")
    end

    it "labels the decline the same way the ledger item page does" do
      raw = create_card_authorization(stripe_reason: "insufficient_funds", hcb_reason: "user_cards_locked")
      create(:canonical_pending_transaction, ledger_item:, memo: "Lunch", raw_pending_stripe_transaction: raw).decline!

      text = render_transactions

      expect(text).to include("↳ Declined")
      expect(text).to include("Card locked due to overdue receipts")
      expect(text).not_to include("Insufficient funds")
    end

    context "when it isn't a card authorization" do
      let(:event) { create(:event, :with_positive_balance) }

      before do
        # Wires look up their recipient's bank at Column on creation.
        stub_request(:get, /api\.column\.com\/institutions\/.*/)
          .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
      end

      it "falls back to the reason recorded on the transfer" do
        wire = create(:wire, event:, aasm_state: "rejected", return_reason: "Beneficiary account closed")
        ledger_item.update!(linked_object: wire)
        create(:canonical_pending_transaction, ledger_item:, wire:, memo: "Wire out").decline!

        text = render_transactions

        expect(text).to include("Wire out ↳ Declined")
        expect(text).to include("Beneficiary account closed")
        expect(text).not_to include("Unknown error")
      end

      it "shows the transfer's state when it recorded no reason" do
        wire = create(:wire, event:, aasm_state: "rejected")
        ledger_item.update!(linked_object: wire)
        create(:canonical_pending_transaction, ledger_item:, wire:, memo: "Wire out").decline!

        text = render_transactions

        expect(text).to include("Wire out ↳ Declined")
        expect(text).to include("Rejected")
        expect(text).not_to include("Unknown error")
      end
    end
  end

  describe "a settled pending transaction" do
    let!(:cpt) { create(:canonical_pending_transaction, ledger_item:, memo: "Lunch", date: Date.new(2026, 1, 10)) }

    it "groups the canonical transaction under the pending transaction it settled from" do
      ct = create(:canonical_transaction, ledger_item:, memo: "Lunch", date: Date.new(2026, 1, 11))
      create(:canonical_pending_settled_mapping, canonical_pending_transaction: cpt, canonical_transaction: ct)
      create(:canonical_transaction, ledger_item:, memo: "Tip", date: Date.new(2026, 1, 12))

      text = render_transactions

      # Rendered once, nested under the pending transaction, rather than as its own row too.
      expect(text.scan("Lunch").size).to eq(2)
      expect(text).to include("Created Jan 10, 2026 #{cpt.amount.format} Lunch ↳ Settled Jan 11, 2026 #{ct.amount.format} Lunch Updated Jan 12, 2026")
      expect(labels(text)).to eq(%w[Created Settled Updated])
    end

    it "leaves a canonical transaction that has since moved to another ledger item to that ledger item" do
      ct = create(:canonical_transaction, ledger_item:, memo: "Moved elsewhere", date: Date.new(2026, 1, 11))
      create(:canonical_pending_settled_mapping, canonical_pending_transaction: cpt, canonical_transaction: ct)
      ct.update!(ledger_item: create(:ledger_item))

      text = render_transactions

      expect(text).to include("Lunch")
      expect(text).not_to include("Moved elsewhere")
      expect(text).not_to include("↳")
    end
  end

  describe "standalone canonical transactions" do
    it "labels the first row Created, the first settlement Settled, and later rows Updated" do
      create(:canonical_pending_transaction, ledger_item:, memo: "Lunch", date: Date.new(2026, 1, 10))
      create(:canonical_transaction, ledger_item:, memo: "Lunch", date: Date.new(2026, 1, 11))
      create(:canonical_transaction, ledger_item:, memo: "Tip", date: Date.new(2026, 1, 12))

      text = render_transactions

      expect(labels(text)).to eq(%w[Created Settled Updated])
      expect(text).not_to include("↳")
    end

    it "labels a canonical transaction with no pending transaction Created" do
      create(:canonical_transaction, ledger_item:, memo: "Lunch")

      text = render_transactions

      expect(labels(text)).to eq(%w[Created])
    end
  end
end
