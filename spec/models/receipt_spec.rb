# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipt, type: :model do
  let(:user) { create(:user) }
  let(:hcb_code) { create(:hcb_code) }

  def build_receipt(attributes = {})
    described_class.new(receiptable: hcb_code, upload_method: :api, **attributes).tap do |receipt|
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png",
        content_type: "image/png"
      )
    end
  end

  describe "card locking" do
    # Unlock-only, so that attaching or removing a receipt can never be the thing
    # that locks someone's cards.
    it "re-evaluates card locking when a receipt is created" do
      expect { build_receipt(user:).save! }
        .to have_enqueued_job(User::UpdateCardLockingJob).with(user:, unlock_only: true)
    end

    it "re-evaluates card locking when a receipt is destroyed" do
      receipt = build_receipt(user:)
      receipt.save!

      expect { receipt.destroy! }
        .to have_enqueued_job(User::UpdateCardLockingJob).with(user:, unlock_only: true)
    end

    it "does not enqueue anything for a receipt with no user" do
      expect { build_receipt(user: nil).save! }
        .not_to have_enqueued_job(User::UpdateCardLockingJob)
    end
  end
end
