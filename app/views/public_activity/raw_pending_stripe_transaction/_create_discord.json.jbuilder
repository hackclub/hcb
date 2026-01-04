# frozen_string_literal: true

current_user ||= local_assigns[:p][:current_user]
hcb_code = activity.trackable&.canonical_pending_transaction&.hcb_code
local_hcb_code = hcb_code ? HcbCode.find_or_create_by(hcb_code:) : nil
user = activity.user&.name

json.embed do
  if local_hcb_code.present?
    if local_hcb_code.stripe_refund?
      json.description "#{user} was refunded #{render_money(local_hcb_code.amount_cents.abs)} from #{local_hcb_code.memo} for #{Discord.link_to(local_hcb_code.event&.name, event_url(local_hcb_code.event))}"
    elsif local_hcb_code.pt&.declined?
      json.description "#{possessive(user)} #{Discord.link_to(local_hcb_code.event&.name, event_url(local_hcb_code.event))} card was declined for #{render_money(activity.trackable.amount_cents.abs)} at #{local_hcb_code.memo}"
    elsif local_hcb_code.stripe_cash_withdrawal?
      json.description "#{user} withdrew #{render_money(local_hcb_code.stripe_atm_fee ? local_hcb_code.amount_cents.abs - local_hcb_code.stripe_atm_fee : local_hcb_code.amount_cents.abs)} from #{humanized_merchant_name(local_hcb_code.stripe_merchant)} for #{Discord.link_to(local_hcb_code.event&.name, event_url(local_hcb_code.event))}"
    else
      json.description "#{user} spent #{render_money(local_hcb_code.amount_cents.abs)} on #{Discord.link_to(local_hcb_code.memo, hcb_code_url(local_hcb_code))} for #{Discord.link_to(local_hcb_code.event&.name, event_url(local_hcb_code.event))}"
    end
  else
    json.description "#{user} spent #{render_money(activity.trackable.amount_cents.abs)} on #{activity.trackable.memo}"
  end

end

json.components Discord.button_to("Attach receipt", "attach_receipt", style: 3, emoji: Discord.emoji_icon(:payment_docs))
