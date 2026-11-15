# frozen_string_literal: true

require "rails_helper"

RSpec.describe LostReceipt::Statement do
  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }
  let(:details) do
    { date: Date.current, merchant: "Stationery Shop", purpose: "Workshop supplies", signer_name: "Alex Example", confirmed: true,
      items_attributes: [{ description: "Notebooks", quantity: 3, unit_amount_cents: 127 },
                         { description: "Pens", quantity: 2, unit_amount_cents: 249 }]
}
  end

  before { allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4") }

  it "generates an itemized PDF with exact integer-cent totals" do
    statement = described_class.new(details.merge(items_attributes: {
                                                    "0" => { description: "Notebooks", quantity: "3", unit_amount: "1.27" },
                                                    "2" => { description: "Pens", quantity: "2", unit_amount: "2.49" }
                                                  }))

    expect(statement.submit(receiptable: hcb_code)).to eq(true)
    expect(statement.total_amount_cents).to eq(879)
    expect(statement.items.map(&:total_amount_cents)).to eq([381, 498])
    expect(statement.receipt.file.download).to start_with("%PDF")
    expect(CloudflareBrowserRun).to have_received(:pdf).with(
      a_string_including("View transaction", "Notebooks", "Pens", "$8.79", Rails.application.routes.url_helpers.hcb_code_url(hcb_code))
    )
    expect(statement.confirmed_at).to be_present
    expect(statement.receipt.reload).to be_lost_receipt_statement
  end

  it "requires complete, confirmed details and valid quantities and amounts" do
    [details.merge(confirmed: false), details.except(:confirmed), details.merge(date: Date.tomorrow),
     details.merge(purpose: ""), details.merge(signer_name: ""), details.merge(items_attributes: []),
     details.merge(items_attributes: [{ description: "Pens", quantity: "1.5", unit_amount_cents: 100 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 0, unit_amount_cents: 100 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount_cents: -1 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount: "NaN" }])].each do |invalid_details|
      statement = described_class.new(invalid_details)
      expect(statement.submit(receiptable: hcb_code)).to eq(false)
      expect(statement.errors).to be_present
    end
    expect(hcb_code.receipts).to be_empty
  end

  context "on an organization's transaction" do
    let(:event) { create(:event) }
    let(:cardholder) { create(:user) }
    let(:hcb_code) do
      transaction = create(:canonical_pending_transaction, amount_cents: -100)
      create(:canonical_pending_event_mapping, canonical_pending_transaction: transaction, event:)
      transaction.local_hcb_code
    end
    let(:sentence) { "I understand this is the 1st receipt my organization has lost. Continually losing receipts will result in termination of my organization." }

    it "requires the typed acknowledgement and counts the lost receipt against the organization" do
      statement = described_class.new(details.merge(receiptable: hcb_code, acknowledgement: "I understand"))
      expect(statement.required_acknowledgement).to eq(sentence)
      expect(statement.submit).to eq(false)
      expect(statement.errors[:acknowledgement]).to be_present

      statement.acknowledgement = "  #{sentence.upcase.delete('.')} "
      expect(statement.submit).to eq(true)
      expect(event.lost_receipt_filings.sole).to have_attributes(receipt: statement.receipt, user: nil)
      expect(described_class.new(receiptable: hcb_code).required_acknowledgement).to include("2nd receipt my organization has lost.")

      statement.receipt.destroy!
      expect(event.lost_receipt_filings).to be_empty
    end

    it "counts card charges against the cardholder, who is the only one asked to own them" do
      allow(hcb_code).to receive(:stripe_cardholder).and_return(double(user: cardholder))
      earlier = create(:canonical_pending_transaction).local_hcb_code
      allow(earlier).to receive(:stripe_cardholder).and_return(double(user: cardholder))
      expect(described_class.new(details).submit(receiptable: earlier)).to eq(true)

      [cardholder, nil].each do |submitter|
        expect(described_class.new(receiptable: hcb_code, submitter:).required_acknowledgement)
          .to include("1st receipt my organization has lost, and the 2nd receipt I have lost.")
      end

      statement = described_class.new(details.merge(receiptable: hcb_code, submitter: create(:user)))
      expect(statement.required_acknowledgement).to eq(sentence)
      statement.acknowledgement = sentence
      expect(statement.submit).to eq(true)
      expect(cardholder.lost_receipt_filings.count).to eq(2)
    end
  end

  it "does not resolve the missing receipt if PDF generation fails" do
    allow(CloudflareBrowserRun).to receive(:pdf).and_raise(Faraday::TimeoutError)

    statement = described_class.new(details)
    expect(statement.submit(receiptable: hcb_code)).to eq(false)
    expect(statement.errors[:base]).to include("The PDF couldn't be generated. Please try again.")
    expect(hcb_code.receipts).to be_empty
  end

  it "does not resolve the missing receipt if storing the PDF fails" do
    service = ActiveStorage::Blob.service
    key = nil
    allow(service).to receive(:upload).and_wrap_original do |upload, *args, **options|
      key = args.first
      upload.call(*args, **options)
      raise ActiveStorage::IntegrityError
    end

    statement = described_class.new(details)
    expect {
      expect(statement.submit(receiptable: hcb_code)).to eq(false)
    }.not_to change(ActiveStorage::Blob, :count)
    expect(service.exist?(key)).to eq(false)
    expect(hcb_code.receipts).to be_empty
  end
end
