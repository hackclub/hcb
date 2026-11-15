# frozen_string_literal: true

# locals: (activity:, p:)

ledger_item = activity.trackable&.canonical_pending_transaction&.ledger_item
card_charge = ledger_item&.linked_object
event = ledger_item&.primary_ledger&.event || ledger_item&.primary_ledger&.card_grant&.event
user = activity.user&.name

json.embed do
  if ledger_item.present?
    if card_charge&.stripe_refund?
      json.description "#{user} was refunded #{render_money(ledger_item.amount_cents.abs)} from #{ledger_item.memo} for #{Discord.link_to(event&.name, event_url(event))}"
    elsif ledger_item.declined?
      json.description "#{possessive(user)} #{Discord.link_to(event&.name, event_url(event))} card was declined for #{render_money(activity.trackable.amount_cents.abs)} at #{ledger_item.memo}"
    elsif card_charge&.stripe_cash_withdrawal?
      json.description "#{user} withdrew #{render_money(card_charge.stripe_atm_fee ? ledger_item.amount_cents.abs - card_charge.stripe_atm_fee : ledger_item.amount_cents.abs)} from #{humanized_merchant_name(card_charge.stripe_merchant_data)} for #{Discord.link_to(event&.name, event_url(event))}"
    else
      json.description "#{user} spent #{render_money(ledger_item.amount_cents.abs)} on #{Discord.link_to(ledger_item.memo, ledger_item_url(ledger_item))} for #{Discord.link_to(event&.name, event_url(event))}"
    end
  else
    json.description "#{user} spent #{render_money(activity.trackable.amount_cents.abs)} on #{activity.trackable.memo}"
  end

end

components = []
components << Discord.button_to("View transaction", ledger_item_url(ledger_item)) if ledger_item.present?
components << Discord.button_to("Attach receipt", "attach_receipt", style: 3, emoji: Discord.emoji_icon(:payment_docs))
json.components components
