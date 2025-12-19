# frozen_string_literal: true

class ReceiptableMailerPreview < ActionMailer::Preview
  def initialize( params = {} )
    super( params )
  end

  def receipt_report
    user = User.find_by(email: "max@hackclub.com")
    user_id = user.id
    # Normally this would be just requiring receipt, but this shows all
    hcb_ids = user.stripe_cards.map{ |c| c.local_hcb_codes }.flatten
    ReceiptableMailer.with(
      user_id:,
      hcb_ids:
    ).receipt_report
  end

end
