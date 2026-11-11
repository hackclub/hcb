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

    it "does not enqueue anything for a receiptable that is not a card charge" do
      expect { build_receipt(receiptable: create(:hcb_code), user: uploader).save! }
        .not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end

  describe "#extract_textual_content" do
    def create_receipt_with(fixture:, content_type:)
      described_class.new(user: create(:user), upload_method: :api).tap do |receipt|
        receipt.file.attach(
          io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files", fixture))),
          filename: fixture,
          content_type:
        )
        receipt.save!
      end
    end

    it "extracts text from a PDF with pdf-reader" do
      receipt = create_receipt_with(fixture: "receipt.pdf", content_type: "application/pdf")

      result = receipt.extract_textual_content

      expect(result[:textual_content_source]).to eq(:pdf_text)
      expect(result[:text]).to include("HCB Test Merchant")
      expect(result[:text]).to include("Order #48213")
      expect(result[:text]).to include("Total: $12.34")
    end

    it "skips image OCR without reporting an error when tesseract is not installed" do
      allow(described_class).to receive(:tesseract_available?).and_return(false)
      receipt = create_receipt_with(fixture: "receipt.png", content_type: "image/png")

      expect(Rails.error).not_to receive(:report)
      expect(RTesseract).not_to receive(:new)

      expect(receipt.extract_textual_content).to eq(text: "", textual_content_source: :tesseract_ocr_text)
    end
  end
end
