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

    it "lets a receipt of a type we no longer accept be copied" do
      receipt = build_receipt(receiptable: create(:hcb_code), user: create(:user))
      receipt.file.attach(io: StringIO.new("x"), filename: "receipt.gif", content_type: "image/gif")
      receipt.save!(validate: false) # uploaded before the rule
      copy_to = create(:hcb_code)

      expect { described_class.reupload(old_receiptable: receipt.receiptable, new_receiptable: copy_to) }
        .to change { described_class.where(receiptable: copy_to).count }.by(1)
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
