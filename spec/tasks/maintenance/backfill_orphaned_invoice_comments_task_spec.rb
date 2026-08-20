# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillOrphanedInvoiceCommentsTask do
  let(:user) { create(:user) }

  def create_invoice
    expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
    create(:invoice)
  end

  describe "#collection" do
    it "includes comments on an invoice-type HcbCode with no ledger_item" do
      invoice = create_invoice
      comment = create(:comment, commentable: invoice.local_hcb_code, user:)

      expect(described_class.new.collection).to include(comment)
    end

    it "excludes comments on an HcbCode with a ledger_item" do
      invoice = create_invoice
      hcb_code = invoice.local_hcb_code
      hcb_code.update!(ledger_item: create(:ledger_item))
      comment = create(:comment, commentable: hcb_code, user:)

      expect(described_class.new.collection).not_to include(comment)
    end

    it "includes soft-deleted comments" do
      invoice = create_invoice
      comment = create(:comment, commentable: invoice.local_hcb_code, user:)
      comment.destroy

      expect(described_class.new.collection).to include(comment)
    end
  end

  describe "#process" do
    it "moves the comment to the HcbCode's Invoice" do
      invoice = create_invoice
      comment = create(:comment, commentable: invoice.local_hcb_code, user:)

      described_class.new.process(comment)

      expect(comment.reload.commentable).to eq(invoice)
    end

    it "leaves non-invoice orphan comments alone" do
      hcb_code = create(:hcb_code, code_type: ::TransactionGroupingEngine::Calculate::HcbCode::UNKNOWN_CODE)
      comment = create(:comment, commentable: hcb_code, user:)

      described_class.new.process(comment)

      expect(comment.reload.commentable).to eq(hcb_code)
    end
  end
end
