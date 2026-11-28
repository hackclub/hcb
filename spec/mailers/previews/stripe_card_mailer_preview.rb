# frozen_string_literal: true

class StripeCardMailerPreview < ActionMailer::Preview
  def physical_card_ordered
    @card_id = StripeCard.physical.last.id
    @eta = 1.week.from_now
    StripeCardMailer.with(card_id: @card_id, eta: @eta).physical_card_ordered
  end

  def virtual_card_ordered
    @card_id = StripeCard.virtual.last.id
    StripeCardMailer.with(card_id: @card_id).virtual_card_ordered
  end

  def expiring_soon
    StripeCardMailer.with(card_id: StripeCard.last.id).expiring_soon
  end

  def expired
    StripeCardMailer.with(card_id: StripeCard.last.id).expired
  end

end
