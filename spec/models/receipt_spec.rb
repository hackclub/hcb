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

  # Real Tesseract and ImageMagick, no mocks.
  describe "#auto_rotate!" do
    let(:upright) { Rails.root.join("spec/fixtures/files/rotation_receipt.png").to_s }

    def receipt_turned(degrees)
      described_class.new(receiptable: create(:hcb_code), user: create(:user), upload_method: :api).tap do |receipt|
        receipt.file.attach(
          io: ImageProcessing::MiniMagick.source(upright).rotate(degrees).call,
          filename: "receipt.png",
          content_type: "image/png"
        )
        receipt.save!
      end
    end

    def rotation_needed(receipt)
      receipt.file.blob.open { |file| ReceiptService::DetectRotation.new(path: file.path).run }
    end

    it "is queued when an image receipt is uploaded" do
      expect { receipt_turned(0) }.to have_enqueued_job(Receipt::AutoRotateJob)
    end

    [90, 180, 270].each do |degrees|
      it "turns a receipt uploaded #{degrees} degrees clockwise upright and keeps the upload" do
        receipt = receipt_turned(degrees)
        upload = receipt.file.blob

        perform_enqueued_jobs { receipt.auto_rotate! }
        receipt.reload

        expect(rotation_needed(receipt)).to be_nil
        expect(receipt.file.blob).not_to eq(upload)
        expect(MiniMagick::Image.read(receipt.file.download).dimensions).to eq([542, 735])
        expect(receipt.file.filename.to_s).to eq("receipt.png")
        expect(receipt.file.content_type).to eq("image/png")
        # the purge job for the replaced attachment has run by now
        expect(receipt.original_file.blob).to eq(upload)
        expect(upload.reload.download).to be_present
      end
    end

    it "can be undone, and doesn't rotate again afterwards" do
      receipt = receipt_turned(90)
      upload = receipt.file.blob
      receipt.auto_rotate!

      receipt.restore_original_file!
      expect(receipt.reload.file.blob).to eq(upload)

      expect { receipt.auto_rotate! }.not_to(change { receipt.reload.file.blob })
    end

    it "leaves an upright receipt alone" do
      receipt = receipt_turned(0)

      expect { receipt.auto_rotate! }.not_to(change { receipt.reload.file.blob })
      expect(receipt.original_file).not_to be_attached
    end

    it "is not triggered by text extraction" do
      receipt = receipt_turned(90)

      expect { receipt.extract_textual_content! }.not_to(change { receipt.reload.file.blob })
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
