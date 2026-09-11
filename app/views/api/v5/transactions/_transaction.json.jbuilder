# frozen_string_literal: true

# locals: (json:, tx:)

# Renders `HcbCode`, `CanonicalPendingTransaction`, and
# `CanonicalTransactionGrouped` instances.

hcb_code = tx.is_a?(HcbCode) ? tx : tx.local_hcb_code
is_cpt = tx.is_a?(CanonicalPendingTransaction)
is_hcb_code = tx.is_a?(HcbCode)
amount = transaction_amount(tx, event: @event)

object_shape(json, hcb_code, object_name: "transaction", created_at: false) do |f|
  f.date tx.date
  f.amount_cents amount
  f.memo { hcb_code.memo(event: @event) }
  f.has_custom_memo { hcb_code.custom_memo.present? }
  f.pending((is_cpt && tx.unsettled?) || (is_hcb_code && !tx.pt&.fronted? && tx.pt&.unsettled?))
  f.declined((is_cpt && tx.declined?) || (is_hcb_code && tx.pt&.declined?))
  f.reversed((is_cpt && tx.raw_pending_stripe_transaction&.stripe_transaction&.dig("status") == "reversed") || (is_hcb_code && tx.stripe_reversed_by_merchant?))
  f.code { hcb_code.hcb_i1 }
  f.missing_receipt { hcb_code.missing_receipt?(@event) }
  f.lost_receipt { hcb_code.no_or_lost_receipt? }
  f.appearance { hcb_code.incoming_disbursement&.special_appearance_name }

  f.nest(:tags) do
    json.array! hcb_code.tags do |tag|
      json.partial! "api/v5/tags/tag", tag: tag
    end
  end

  f.nest(:card_charge)    { json.partial! "api/v5/transactions/card_charge",    hcb_code:                                                   } if hcb_code.stripe_card? || hcb_code.stripe_force_capture?
  f.nest(:donation)       { json.partial! "api/v5/transactions/donation",       donation:       hcb_code.donation                           } if hcb_code.donation?
  f.nest(:expense_payout) { json.partial! "api/v5/transactions/expense_payout", expense_payout: hcb_code.reimbursement_expense_payout       } if hcb_code.reimbursement_expense_payout?
  f.nest(:invoice)        { json.partial! "api/v5/transactions/invoice",        invoice:        hcb_code.invoice                            } if hcb_code.invoice?
  f.nest(:check)          { json.partial! "api/v5/transactions/check",          check:          hcb_code.check                              } if hcb_code.check?
  f.nest(:check)          { json.partial! "api/v5/transactions/check",          check:          hcb_code.increase_check                     } if hcb_code.increase_check?
  f.nest(:transfer)       { json.partial! "api/v5/transactions/disbursement",   disbursement:   hcb_code.incoming_disbursement.disbursement } if hcb_code.incoming_disbursement?
  f.nest(:transfer)       { json.partial! "api/v5/transactions/disbursement",   disbursement:   hcb_code.outgoing_disbursement.disbursement } if hcb_code.outgoing_disbursement?
  f.nest(:ach_transfer)   { json.partial! "api/v5/transactions/ach_transfer",   ach_transfer:   hcb_code.ach_transfer                       } if hcb_code.ach_transfer?
  f.nest(:check_deposit)  { json.partial! "api/v5/transactions/check_deposit",  check_deposit:  hcb_code.check_deposit                      } if hcb_code.check_deposit?
  f.nest(:wise_transfer)  { json.partial! "api/v5/transactions/wise_transfer",  wise_transfer:  hcb_code.wise_transfer                      } if hcb_code.wise_transfer?
  f.nest(:wire_transfer)  { json.partial! "api/v5/transactions/wire_transfer",  wire_transfer:  hcb_code.wire                               } if hcb_code.wire?

  expand_association(f, json, :organization, hcb_code.event, partial: "api/v5/events/event", as: :event)
end
