# frozen_string_literal: true

class CardChargeMailerPreview < ActionMailer::Preview
  def reversed
    CardChargeMailer.with(ledger_item:).reversed
  end

  def amount_updated
    CardChargeMailer.with(ledger_item:, previous_amount_cents: -50_00, amount_cents: -30_00).amount_updated
  end

  private

  def ledger_item
    CardCharge.last.ledger_item
  end

end
