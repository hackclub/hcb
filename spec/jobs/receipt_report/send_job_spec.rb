# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptReport::SendJob do
  include_context "card locking charges"

  it "mails the cardholder the card charges missing a receipt" do
    charge = create_settled_card_charge(user:, settled_at: 2.days.ago)
    create_settled_card_charge(user:, settled_at: 3.days.ago, uploaded_at: 2.days.ago)

    expect { described_class.perform_now(user.id) }
      .to have_enqueued_mail(ReceiptableMailer, :receipt_report).with(params: { user_id: user.id, ledger_item_ids: [charge.id] }, args: [])
  end

  it "sends nothing when no charge is missing a receipt" do
    create_settled_card_charge(user:, settled_at: 3.days.ago, uploaded_at: 2.days.ago)

    expect { described_class.perform_now(user.id) }.not_to have_enqueued_mail(ReceiptableMailer, :receipt_report)
  end
end
