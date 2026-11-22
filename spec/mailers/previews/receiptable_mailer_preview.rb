# frozen_string_literal: true

class ReceiptableMailerPreview < ActionMailer::Preview
  def initialize( params = {} )
    super( params )
  end

  def receipt_report
    user = User.first
    user_id = user.id
    # Normally this would be just the charges missing a receipt, but this shows all
    ledger_item_ids = Ledger::Item.card_charges_for_cardholder(user_id).pluck(:id)
    ReceiptableMailer.with(
      user_id:,
      ledger_item_ids:
    ).receipt_report
  end

end
