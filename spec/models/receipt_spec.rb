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
  describe "auto rotation on upload" do
    let(:upright) { Rails.root.join("spec/fixtures/files/rotation_receipt.png").to_s }

    def new_receipt(io:, content_type: "image/png", filename: "receipt.png", **attributes)
      described_class.new(receiptable: create(:hcb_code), user: create(:user), upload_method: :api, **attributes).tap do |receipt|
        receipt.file.attach(io:, filename:, content_type:)
      end
    end

    def receipt_turned(degrees, **attributes)
      new_receipt(io: ImageProcessing::MiniMagick.source(upright).rotate(degrees).call, **attributes).tap(&:save!)
    end

    def rotation_needed(receipt)
      receipt.file.blob.open { |file| ReceiptService::DetectRotation.new(path: file.path).run }
    end

    [90, 180, 270].each do |degrees|
      it "turns a receipt uploaded #{degrees} degrees clockwise upright and keeps the upload" do
        receipt = perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { receipt_turned(degrees) }

        # the same instance the uploader's request holds already sees the upright file
        expect(rotation_needed(receipt)).to be_nil
        expect(MiniMagick::Image.read(receipt.file.download).dimensions).to eq([542, 735])
        expect(receipt.file.filename.to_s).to eq("receipt.png")
        expect(receipt.file.content_type).to eq("image/png")
        # the purge job for the replaced attachment has run by now
        expect(receipt.original_file.blob).not_to eq(receipt.file.blob)
        expect(rotation_needed(described_class.new(file: receipt.original_file.blob))).to eq(360 - degrees)
      end
    end

    it "rotates before pairing suggestions run or are queued" do
      seen = []
      allow(ReceiptService::Suggest).to receive(:new) do |receipt:|
        seen << receipt.original_file.attached?
        instance_double(ReceiptService::Suggest, run!: nil)
      end

      ReceiptService::Create.new(
        attachments: [{ io: ImageProcessing::MiniMagick.source(upright).rotate(90).call, filename: "receipt.png", content_type: "image/png" }],
        uploader: create(:user), upload_method: :quick_expense, receiptable: create(:hcb_code)
      ).run!
      expect(seen).to eq([true])

      expect { receipt_turned(90) }.to have_enqueued_job(Receipt::SuggestPairingsJob).with(satisfy { |receipt| receipt.original_file.attached? })
    end

    it "can be undone, and doesn't rotate again afterwards" do
      receipt = receipt_turned(90)
      upload = receipt.original_file.blob

      receipt.restore_original_file!
      expect(receipt.reload.file.blob).to eq(upload)

      expect(receipt.auto_rotate!).to be(false)
      expect(receipt.reload.file.blob).to eq(upload)
    end

    it "leaves an upright receipt alone" do
      receipt = receipt_turned(0)

      expect(receipt.original_file).not_to be_attached
      expect(MiniMagick::Image.read(receipt.file.download).dimensions).to eq([542, 735])
    end

    it "changes nothing when the rotated copy can't be saved" do
      receipt = receipt_turned(0)
      upload = receipt.file.blob
      allow(ReceiptService::DetectRotation).to receive(:new).and_return(instance_double(ReceiptService::DetectRotation, run: 90))
      allow_any_instance_of(described_class).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

      expect(receipt.auto_rotate).to be(false)

      receipt.reload
      expect(receipt.file.blob).to eq(upload)
      expect(receipt.original_file).not_to be_attached
    end

    it "keeps a PNG a PNG when the upload has no file extension" do
      # SMS receipts are named like this
      receipt = new_receipt(io: ImageProcessing::MiniMagick.source(upright).rotate(90).call, filename: "SMS_2026-11-14").tap(&:save!)

      expect(receipt.original_file).to be_attached
      expect(MiniMagick::Image.read(receipt.file.download).type).to eq("PNG")
    end

    it "doesn't check copies of receipts again" do
      expect(ReceiptService::DetectRotation).not_to receive(:new)

      receipt_turned(90, upload_method: :duplicate)
    end

    it "still saves a receipt whose image can't be read" do
      allow(Rails.error).to receive(:report)
      receipt = new_receipt(io: StringIO.new("not really a png"))

      expect { receipt.save! }.not_to raise_error
      expect(receipt.original_file).not_to be_attached
      expect(Rails.error).not_to have_received(:report)
    end

    it "does nothing if the receipt was deleted meanwhile" do
      receipt = receipt_turned(0)
      stale = described_class.find(receipt.id)
      allow(ReceiptService::DetectRotation).to receive(:new).and_return(instance_double(ReceiptService::DetectRotation, run: 90))
      allow(Rails.error).to receive(:report)
      receipt.destroy!

      expect { stale.auto_rotate }.not_to change(ActiveStorage::Attachment, :count)
    end
  end

  describe "file types" do
    def receipt_with(filename, content_type)
      build_receipt(receiptable: create(:hcb_code), user: create(:user)).tap do |receipt|
        receipt.file.attach(io: StringIO.new("x"), filename:, content_type:)
      end
    end

    {
      "receipt.pdf"  => "application/pdf",
      "receipt.jpg"  => "image/jpeg",
      "receipt.heic" => "image/heic",
      "invoice.docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "invoice.doc"  => "application/msword",
      "orders.csv"   => "text/csv",
      "orders.xlsx"  => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }.each do |filename, content_type|
      it "accepts #{filename}" do
        expect(receipt_with(filename, content_type)).to be_valid
      end
    end

    { "party.gif" => "image/gif", "logo.svg" => "image/svg+xml", "scan.tiff" => "image/tiff", "notes.txt" => "text/plain" }.each do |filename, content_type|
      it "rejects #{filename}" do
        receipt = receipt_with(filename, content_type)

        expect(receipt).not_to be_valid
        expect(receipt.errors[:file].sole).to start_with("must be a PDF")
      end
    end

    it "doesn't invalidate receipts that already have another type" do
      receipt = receipt_with("party.gif", "image/gif").tap { |r| r.save!(validate: false) }

      expect(described_class.find(receipt.id).update(textual_content: "hello")).to be(true)
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
