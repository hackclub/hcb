# frozen_string_literal: true

# This partial is capable of rendering `HcbCode`, `CanonicalPendingTransaction`, and `CanonicalTransactionGrouped` instances

hcb_code = tx.is_a?(HcbCode) ? tx : tx.local_hcb_code
amount = transaction_amount(tx, event: @event)

json.id hcb_code.public_id
json.date tx.date
json.amount_cents amount
json.memo hcb_code.memo(event: @event)
json.has_custom_memo hcb_code.custom_memo.present?
json.pending (tx.is_a?(CanonicalPendingTransaction) && tx.unsettled?) || (tx.is_a?(HcbCode) && !tx.pt&.fronted? && tx.pt&.unsettled?)
json.declined (tx.is_a?(CanonicalPendingTransaction) && tx.declined?) || (tx.is_a?(HcbCode) && tx.pt&.declined?)
if Flipper.enabled?(:transaction_tags_2022_07_29, @event)
  json.tags hcb_code.tags do |tag|
    json.id tag.public_id
    json.label tag.label
  end
else
  json.tags []
end
json.code hcb_code.hcb_i1
json.missing_receipt hcb_code.missing_receipt?
json.lost_receipt hcb_code.no_or_lost_receipt?
json.appearance hcb_code.disbursement.special_appearance_name if hcb_code.disbursement&.special_appearance? && amount.positive?

if current_user&.admin?
  json._debug do
    json.hcb_code hcb_code.hcb_code
  end
end

json.card_charge   { json.partial! "api/v4/transactions/card_charge",   hcb_code:                               } if hcb_code.stripe_card? || hcb_code.stripe_force_capture?
json.donation      { json.partial! "api/v4/transactions/donation",      donation:     hcb_code.donation         } if hcb_code.donation?
json.invoice       { json.partial! "api/v4/transactions/invoice",       invoice:      hcb_code.invoice          } if hcb_code.invoice?
json.check         { json.partial! "api/v4/transactions/check",         check:        hcb_code.check            } if hcb_code.check?
json.check         { json.partial! "api/v4/transactions/check",         check:        hcb_code.increase_check   } if hcb_code.increase_check?
json.transfer      { json.partial! "api/v4/transactions/disbursement",  disbursement: hcb_code.disbursement     } if hcb_code.disbursement?
json.ach_transfer  { json.partial! "api/v4/transactions/ach_transfer",  ach_transfer: hcb_code.ach_transfer     } if hcb_code.ach_transfer?
json.check_deposit { json.partial! "api/v4/transactions/check_deposit", check_deposit: hcb_code.check_deposit   } if hcb_code.check_deposit?

json.organization hcb_code.event, partial: "api/v4/events/event", as: :event if expand?(:organization)
