# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptableMailer, type: :mailer do
  include_context "card locking charges"

  describe "#receipt_report" do
    it "links each charge to its upload page that works without signing in" do
      charge = create_settled_card_charge(user:, settled_at: 2.days.ago)

      mail = described_class.with(user_id: user.id, ledger_item_ids: [charge.id]).receipt_report

      expect((mail.html_part || mail).body.decoded).to include("/hcb/#{charge.hcb_code.hashid}/attach_receipt?s=")
    end
  end
end
