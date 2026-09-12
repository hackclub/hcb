# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::Models::LedgerTransaction do
  let(:event) { create(:event) }
  let(:item) { create(:ledger_item, datetime: Time.zone.parse("2026-08-27 14:30:00")) }
  let(:transaction) { described_class.new(item) }

  before do
    Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
  end

  describe ".requested?" do
    def request_for(headers) = ActionDispatch::Request.new(headers)

    it "is true for the ledger header" do
      expect(described_class.requested?(request_for(described_class::ENV_KEY => "ledger"))).to be true
    end

    it "is case insensitive" do
      expect(described_class.requested?(request_for(described_class::ENV_KEY => "Ledger"))).to be true
    end

    it "is false without the header" do
      expect(described_class.requested?(request_for({}))).to be false
    end

    it "is false for any other value" do
      expect(described_class.requested?(request_for(described_class::ENV_KEY => "hcb_code"))).to be false
    end
  end

  describe ".resolve" do
    # AchTransfer validates the event has the funds to cover it.
    let(:funded_event) { create(:event, :with_positive_balance) }
    let(:ach_transfer) { create(:ach_transfer, event: funded_event) }

    it "returns the HcbCode when the ledger engine was not requested" do
      expect(described_class.resolve(ach_transfer, ledger: false)).to eq(ach_transfer.local_hcb_code)
    end

    it "returns the HcbCode for a linked object with no ledger item" do
      allow(ach_transfer).to receive(:ledger_item).and_return(nil)

      expect(described_class.resolve(ach_transfer, ledger: true)).to eq(ach_transfer.local_hcb_code)
    end

    # An AchTransfer builds a canonical pending transaction, which builds and
    # links its own ledger item.
    it "wraps the linked object's ledger item" do
      resolved = described_class.resolve(ach_transfer, ledger: true)

      expect(resolved).to be_a(described_class)
      expect(resolved.ledger_item).to eq(ach_transfer.ledger_item)
    end

    # A disbursement has one ledger item per side, so there is no single item to
    # resolve to and it must fall back rather than pick one arbitrarily.
    it "falls back for an object with no ledger_item association" do
      disbursement = create(:disbursement, event:, source_event: create(:event))

      expect(described_class.resolve(disbursement, ledger: true)).to eq(disbursement.local_hcb_code)
    end
  end

  describe "#type" do
    # Every linked_object_type the ledger records, mapped onto what HcbCode#type
    # returns for the same transaction. Api::Entities::Transaction renames these
    # again for the public payload.
    {
      "Invoice"                      => :invoice,
      "Donation"                     => :donation,
      "AchTransfer"                  => :ach,
      "Check"                        => :check,
      "IncreaseCheck"                => :check,
      "CardCharge"                   => :card_charge,
      "Wire"                         => :wire,
      "WiseTransfer"                 => :wise_transfer,
      "PaypalTransfer"               => :paypal_transfer,
      "CheckDeposit"                 => :check_deposit,
      "BankFee"                      => :bank_fee,
      "Reimbursement::ExpensePayout" => :reimbursement_expense_payout,
      "Disbursement::Outgoing"       => :disbursement,
      "Disbursement::Incoming"       => :disbursement,
      nil                            => :unknown
    }.each do |linked_object_type, expected|
      it "maps #{linked_object_type.inspect} to #{expected.inspect}" do
        item.update_columns(linked_object_type:)

        expect(transaction.type).to eq(expected)
      end
    end

    # HcbCode#type has no branch for these, so it returns nil and the payload
    # carries a null `type`. Matching that keeps the two engines in agreement.
    ["StripeServiceFee", "FeeRevenue", "Reimbursement::PayoutHolding"].each do |linked_object_type|
      it "leaves #{linked_object_type} unmapped, as HcbCode#type does" do
        item.update_columns(linked_object_type:)

        expect(transaction.type).to be_nil
      end
    end

    it "reports a card grant, which the ledger records as an outgoing disbursement" do
      item.update_columns(linked_object_type: "Disbursement::Outgoing")
      allow(item).to receive(:special_appearance).and_return(instance_double(Ledger::Item::SpecialAppearance, key: "card_grant"))

      expect(transaction.type).to eq(:card_grant)
    end
  end

  describe "linked object readers" do
    it "returns the linked object under its matching reader" do
      ach_transfer = create(:ach_transfer, event: create(:event, :with_positive_balance))
      item.update!(linked_object: ach_transfer)

      expect(transaction.ach_transfer?).to be true
      expect(transaction.ach_transfer).to eq(ach_transfer)
    end

    it "returns nil from every other reader" do
      item.update_columns(linked_object_type: "AchTransfer")

      expect(transaction.donation?).to be false
      expect(transaction.donation).to be_nil
      expect(transaction.check).to be_nil
    end

    # HcbCode#check is nil for an IncreaseCheck even though HcbCode#type is
    # :check for both, so Api::Entities::Transaction renders an empty `check`.
    it "keeps IncreaseCheck out of the check reader, as HcbCode does" do
      item.update_columns(linked_object_type: "IncreaseCheck")

      expect(transaction.type).to eq(:check)
      expect(transaction.check).to be_nil
      expect(transaction.increase_check?).to be true
    end
  end

  describe "identity and attributes" do
    it "keeps the HcbCode's public id and exposes the ledger item separately" do
      hcb_code = create(:hcb_code, ledger_item: item)

      expect(transaction.public_id).to eq(hcb_code.public_id)
      expect(transaction.public_id).to start_with("txn_")
      expect(transaction.ledger_item.public_id).to start_with("lit_")
      expect(transaction.local_hcb_code).to eq(hcb_code)
    end

    it "reports a Date, matching HcbCode#date" do
      expect(transaction.date).to eq(Date.new(2026, 8, 27))
    end

    it "resolves the event through the primary ledger" do
      expect(transaction.event).to eq(event)
    end

    it "accepts and ignores the event kwarg on memo, as HcbCode#memo does" do
      expect(transaction.memo(event:)).to eq(item.memo)
    end
  end
end
