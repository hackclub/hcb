# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipt, type: :model do
  def build_receipt(receiptable:, **attributes)
    described_class.new(receiptable:, upload_method: :api, **attributes).tap do |receipt|
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png",
        content_type: "image/png"
      )
    end
  end

  it "rejects an ordinary PDF upload claiming to be a lost receipt statement" do
    charge = create(:canonical_pending_transaction).local_hcb_code
    charge.no_or_lost_receipt!
    pdf = WickedPdf.new.pdf_from_string("<p>An ordinary uploaded PDF</p>")
    file = Rack::Test::UploadedFile.new(StringIO.new(pdf), "application/pdf", original_filename: "receipt.pdf")

    expect {
      ReceiptService::Create.new(receiptable: charge, uploader: create(:user), attachments: [file], upload_method: "lost_receipt_statement").run!
    }.to raise_error(ActiveRecord::RecordInvalid, /Lost receipt statement/)

    expect(charge.receipts).to be_empty
    expect(charge.reload).to be_no_or_lost_receipt
    expect(charge.ledger_item.reload).to be_no_or_lost_receipt

    file.rewind
    receipt = described_class.create!(receiptable: charge, user: create(:user), file:, upload_method: :api)
    expect(receipt.update(upload_method: :lost_receipt_statement)).to eq(false)
    expect(receipt.reload).to be_api
  end

  it "retains the lost receipt marker until the last receipt is removed" do
    transaction = create(:canonical_pending_transaction, amount_cents: -100, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction))
    create(:canonical_pending_event_mapping, canonical_pending_transaction: transaction, event: create(:event))
    charge = transaction.local_hcb_code
    statement = LostReceipt::Statement.new(date: Date.current, merchant: "Stationery Shop", purpose: "Workshop supplies",
                                           signer_name: "Alex Example", confirmed: true,
                                           items_attributes: [{ description: "Notebooks", quantity: 1, unit_amount_cents: 100 }])
    expect(statement.submit(receiptable: charge)).to eq(true)
    receipt = build_receipt(receiptable: charge, user: create(:user))
    receipt.save!
    expect(charge.reload).to be_no_or_lost_receipt
    expect(charge.ledger_item.reload).to be_no_or_lost_receipt

    statement.receipt.destroy!
    expect(charge.reload).not_to be_missing_receipt
    expect(charge).to be_no_or_lost_receipt
    expect(charge.receipts.count).to eq(1)

    later_receipt = build_receipt(receiptable: charge, user: receipt.user)
    later_receipt.save!
    expect(charge.reload).to be_no_or_lost_receipt
    receipt.destroy!
    expect(charge.reload).to be_no_or_lost_receipt

    later_receipt.update!(receiptable: nil)
    expect(charge.reload).to be_missing_receipt
    expect(charge).not_to be_no_or_lost_receipt
    expect(charge.ledger_item.reload).to be_missing_receipt
    expect(charge.ledger_item).not_to be_no_or_lost_receipt
  end

  describe "card locking" do
    include_context "card locking charges"

    # The person who uploads a receipt is not necessarily the cardholder: an org
    # teammate may upload it, or an unauthenticated email-link upload has no user
    # at all. The unlock recompute must target the cardholder on the charge (whose
    # cards are locked), never the uploader.
    let(:uploader) { create(:user) }
    let(:charge) { create_settled_card_charge(user:, settled_at: 3.days.ago) }

    # Unlock-only, so that attaching or removing a receipt can never be the thing
    # that locks someone's cards.
    it "re-evaluates card locking for the cardholder when a receipt is created" do
      expect { build_receipt(receiptable: charge, user: uploader).save! }
        .to have_enqueued_job(User::UpdateCardLockingJob).with(user:, unlock_only: true, notify_progress: true)
    end

    it "targets the cardholder even when the receipt has no user (email-link upload)" do
      expect { build_receipt(receiptable: charge, user: nil).save! }
        .to have_enqueued_job(User::UpdateCardLockingJob).with(user:, unlock_only: true, notify_progress: true)
    end

    it "re-evaluates card locking for the cardholder when a receipt is destroyed" do
      receipt = build_receipt(receiptable: charge, user: uploader)
      receipt.save!

      expect { receipt.destroy! }
        .to have_enqueued_job(User::UpdateCardLockingJob).with(user:, unlock_only: true, notify_progress: false)
    end

    it "clears receipt resolution when the last receipt moves to the receipt bin" do
      charge.no_or_lost_receipt!
      receipt = build_receipt(receiptable: charge, user: uploader)
      receipt.save!
      expect(charge.reload.receipt_resolved_at).to be_present

      receipt.update!(receiptable: nil)

      expect(charge.reload).to be_missing_receipt
      expect(charge.receipt_resolved_at).to be_nil
    end

    it "does not enqueue anything for a receiptable that is not a card charge" do
      expect { build_receipt(receiptable: create(:hcb_code), user: uploader).save! }
        .not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end
end
