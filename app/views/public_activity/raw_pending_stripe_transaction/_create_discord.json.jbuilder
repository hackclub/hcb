# frozen_string_literal: true

# locals: (activity:, p:)

# The ledger item is only created once the raw transaction's import commits, so
# a notification that still got here without one (see
# Discord::ProcessNotificationJob) falls back to the raw transaction and skips
# the link.
item = activity.trackable&.canonical_pending_transaction&.ledger_item
card_charge = item&.linked_object
# A charge on a card grant sits on the grant's ledger, which belongs to the
# grant rather than to its event.
event = item&.primary_ledger&.event || item&.primary_ledger&.card_grant&.event
organization = Discord.link_to(event.name, event_url(event)) if event
for_organization = " for #{organization}" if organization
user = activity.user&.name

json.embed do
  if item.present?
    if card_charge&.stripe_refund?
      json.description "#{user} was refunded #{render_money(item.amount_cents.abs)} from #{item.memo}#{for_organization}"
    elsif item.declined?
      json.description "#{possessive(user)} #{[organization, "card"].compact.join(" ")} was declined for #{render_money(activity.trackable.amount_cents.abs)} at #{item.memo}"
    elsif card_charge&.stripe_cash_withdrawal?
      json.description "#{user} withdrew #{render_money(card_charge.stripe_atm_fee ? item.amount_cents.abs - card_charge.stripe_atm_fee : item.amount_cents.abs)} from #{humanized_merchant_name(card_charge.stripe_merchant_data)}#{for_organization}"
    else
      json.description "#{user} spent #{render_money(item.amount_cents.abs)} on #{Discord.link_to(item.memo, ledger_item_url(item))}#{for_organization}"
    end
  else
    json.description "#{user} spent #{render_money(activity.trackable.amount_cents.abs)} on #{activity.trackable.memo}"
  end
end

json.components [
  (Discord.button_to("View transaction", ledger_item_url(item)) if item.present?),
  Discord.button_to("Attach receipt", "attach_receipt", style: 3, emoji: Discord.emoji_icon(:payment_docs))
].compact
