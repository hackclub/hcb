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

  describe "#extract_textual_content!" do
    let(:receipt) { build_receipt(receiptable: create(:hcb_code), user: create(:user)).tap(&:save!) }
    let(:words) { ("word " * 30).split.map { |w| { word: w, confidence: 99 } } }

    before do
      allow(RTesseract).to receive(:new).and_return(instance_double(RTesseract, to_box: words))
    end

    def dimensions(receipt)
      image = MiniMagick::Image.read(receipt.file.download)
      [image.width, image.height]
    end

    it "rotates the stored image when it was uploaded sideways" do
      allow(ReceiptService::DetectRotation).to receive(:new).and_return(instance_double(ReceiptService::DetectRotation, run: 270))
      expect(dimensions(receipt)).to eq([454, 678])

      expect { receipt.extract_textual_content! }.to(change { receipt.reload.file.blob })

      expect(dimensions(receipt)).to eq([678, 454])
      expect(receipt.file.content_type).to eq("image/png")
      expect(receipt.file.filename.to_s).to eq("receipt.png")
      expect(receipt.textual_content).to be_present
      expect(receipt).to be_tesseract_ocr_text
    end

    it "leaves the stored image alone when it is upright" do
      allow(ReceiptService::DetectRotation).to receive(:new).and_return(instance_double(ReceiptService::DetectRotation, run: nil))

      expect { receipt.extract_textual_content! }.not_to(change { receipt.reload.file.blob })
      expect(dimensions(receipt)).to eq([454, 678])
      expect(receipt.textual_content).to be_present
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
end
