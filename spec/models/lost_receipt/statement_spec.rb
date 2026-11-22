# frozen_string_literal: true

require "rails_helper"

RSpec.describe LostReceipt::Statement do
  let(:hcb_code) { create(:canonical_pending_transaction, amount_cents: -879).local_hcb_code }
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

    expect { expect(statement.submit(receiptable: hcb_code)).to eq(true) }
      .to have_enqueued_job(described_class::AttachPdfJob).with(statement, hcb_code)
    # Marked right away; the PDF follows in the background.
    expect(hcb_code.reload).to be_no_or_lost_receipt
    expect(statement.receipt).to be_nil
    statement.attach_pdf!
    expect(statement.total_amount_cents).to eq(879)
    expect(statement.items.map(&:total_amount_cents)).to eq([381, 498])
    expect(statement.receipt.file.download).to start_with("%PDF")
    expect(CloudflareBrowserRun).to have_received(:pdf).with(
      a_string_including("View transaction", "Notebooks", "Pens", "$8.79", Rails.application.routes.url_helpers.hcb_code_url(hcb_code))
    )
    expect(statement.confirmed_at).to be_present
    expect(statement.receipt.reload).to be_lost_receipt_statement

    saved = statement.receipt.lost_receipt_statement.reload
    expect(saved).to have_attributes(merchant: "Stationery Shop", purpose: "Workshop supplies", signer_name: "Alex Example",
                                     date: Date.current, total_amount_cents: 879, receiptable: hcb_code.ledger_item, submitter: nil)
    expect(saved.items.map(&:description)).to eq(["Notebooks", "Pens"])
    expect(saved.items.first).to have_attributes(description: "Notebooks", quantity: 3, unit_amount_cents: 127)
    expect(saved.items.map(&:total_amount_cents)).to eq([381, 498])

    statement.receipt.destroy!
    expect(described_class.count).to eq(0)
    expect(LostReceipt::Item.count).to eq(0)
  end

  it "requires complete, confirmed details and valid quantities and amounts" do
    [details.merge(confirmed: false), details.except(:confirmed), details.merge(date: Date.tomorrow + 1),
     details.merge(purpose: ""), details.merge(purpose: "a" * 2001), details.merge(signer_name: ""), details.merge(items_attributes: []),
     details.merge(items_attributes: [{ description: "Pens", quantity: "1.5", unit_amount_cents: 100 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 0, unit_amount_cents: 100 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount_cents: -1 }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount: "NaN" }]),
     # Absurdly large numbers are dropped rather than parsed.
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount: "1e999999" }]),
     details.merge(items_attributes: [{ description: "Pens", quantity: 1, unit_amount_cents: 10**80_000 }])].each do |invalid_details|
      statement = described_class.new(invalid_details)
      expect(statement.submit(receiptable: hcb_code)).to eq(false)
      expect(statement.errors).to be_present
    end
    expect(hcb_code.receipts).to be_empty
  end

  it "requires the items to add up to the transaction" do
    statement = described_class.new(details.merge(items_attributes: [{ description: "Notebooks", quantity: 1, unit_amount_cents: 878 }]))

    expect(statement.submit(receiptable: hcb_code)).to eq(false)
    expect(statement.errors[:base]).to include("The items add up to $8.78, but the transaction was $8.79")
    expect(hcb_code.receipts).to be_empty
  end

  it "still attaches the PDF if the signer's account name changes after submitting" do
    user = create(:user, full_name: "Alex Example")
    statement = described_class.new(details.merge(submitter: user))
    expect(statement.submit(receiptable: hcb_code)).to eq(true)

    user.update!(full_name: "Alex Renamed")
    statement.attach_pdf!
    expect(statement.receipt).to be_persisted
  end

  it "leaves the statement without a receipt if PDF generation fails, so the job can retry" do
    statement = described_class.new(details)
    expect(statement.submit(receiptable: hcb_code)).to eq(true)

    allow(CloudflareBrowserRun).to receive(:pdf).and_raise(Faraday::TimeoutError)
    expect { statement.attach_pdf! }.to raise_error(Faraday::TimeoutError)
    expect(statement.reload.receipt).to be_nil
    expect(hcb_code.receipts).to be_empty

    allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4")
    statement.attach_pdf!
    expect(hcb_code.reload.receipts.count).to eq(1)
    # Running the job twice doesn't attach a second copy.
    statement.attach_pdf!
    expect(hcb_code.reload.receipts.count).to eq(1)
  end

  it "does not keep a half-stored PDF if storing it fails" do
    statement = described_class.new(details)
    expect(statement.submit(receiptable: hcb_code)).to eq(true)

    service = ActiveStorage::Blob.service
    key = nil
    allow(service).to receive(:upload).and_wrap_original do |upload, *args, **options|
      key = args.first
      upload.call(*args, **options)
      raise ActiveStorage::IntegrityError
    end

    expect {
      expect { statement.attach_pdf! }.to raise_error(ActiveStorage::IntegrityError)
    }.not_to change(ActiveStorage::Blob, :count)
    expect(service.exist?(key)).to eq(false)
    expect(hcb_code.receipts).to be_empty
  end
end
