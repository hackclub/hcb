# frozen_string_literal: true

class CardChargeMailerPreview < ActionMailer::Preview
  def reversed
    CardChargeMailer.with(ledger_item:).reversed
  end

  private

  def ledger_item
    CardCharge.last.ledger_item
  end

end
