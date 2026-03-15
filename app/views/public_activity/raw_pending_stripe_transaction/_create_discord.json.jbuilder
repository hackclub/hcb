# frozen_string_literal: true

current_user ||= local_assigns[:p][:current_user]
hcb_code = activity.trackable&.canonical_pending_transaction&.local_hcb_code
user = activity.user&.name

json.embed do
  if hcb_code.present?
    if hcb_code.stripe_refund?
      json.description "#{user} was refunded #{render_money(hcb_code.amount_cents.abs)} from #{hcb_code.memo} for #{Discord.link_to(hcb_code.event&.name, event_url(hcb_code.event))}"
    elsif hcb_code.pt&.declined?
      json.description "#{possessive(user)} #{Discord.link_to(hcb_code.event&.name, event_url(hcb_code.event))} card was declined for #{render_money(activity.trackable.amount_cents.abs)} at #{hcb_code.memo}"
    elsif hcb_code.stripe_cash_withdrawal?
      json.description "#{user} withdrew #{render_money(hcb_code.stripe_atm_fee ? hcb_code.amount_cents.abs - hcb_code.stripe_atm_fee : hcb_code.amount_cents.abs)} from #{humanized_merchant_name(hcb_code.stripe_merchant)} for #{Discord.link_to(hcb_code.event&.name, event_url(hcb_code.event))}"
    else
      json.description "#{user} spent #{render_money(hcb_code.amount_cents.abs)} on #{Discord.link_to(hcb_code.memo, hcb_code_url(hcb_code))} for #{Discord.link_to(hcb_code.event&.name, event_url(hcb_code.event))}"
    end
  else
    json.description "#{user} spent #{render_money(activity.trackable.amount_cents.abs)} on #{activity.trackable.memo}"
  end

end

json.components [
  Discord.button_to("View transaction", hcb_code_url("#{TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE}-#{TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}-#{activity.trackable.stripe_transaction_id}")),
  Discord.button_to("Attach receipt", "attach_receipt", style: 3, emoji: Discord.emoji_icon(:payment_docs))
]
