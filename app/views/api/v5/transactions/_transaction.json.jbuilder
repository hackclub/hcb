# frozen_string_literal: true

# locals: (json:, item:)

# v5 transactions are `Ledger::Item`s. The polymorphic subtype comes from
# `linked_object` rather than from a chain of `hcb_code.donation?` predicates.

linked = item.linked_object

object_shape(json, item, object_name: "transaction", created_at: false) do |f|
  f.date item.datetime
  f.amount_cents item.amount_cents
  f.type item.linked_object_type
  f.status item.status
  f.pending item.pending?
  f.code { item.short_code }
  f.has_custom_memo { item.custom_memo.present? }
  f.system_memo { item.system_memo }
  f.missing_receipt { item.missing_receipt? }
  f.lost_receipt { item.marked_no_or_lost_receipt_at.present? }
  f.appearance { item.special_appearance&.key }

  # Account-verification micro-deposits prove ownership of an external account,
  # so their amount is redacted from transparency viewers — the same rule the
  # ledger page applies (`app/views/ledger/_item.html.erb`). The policy decides
  # whether this viewer is an organizer; the serializer picks the value.
  f.memo do
    if item.likely_account_verification_related? && !policy(item).event_reader?
      "Account verification"
    else
      item.memo
    end
  end

  f.nest(:receipts) do
    json.count item.receipt_count
    json.missing item.missing_receipt?
  end

  f.nest(:comments) do
    json.count item.not_admin_only_comment_count
  end

  f.nest(:tags) do
    json.array! item.tags do |tag|
      json.partial! "api/v5/tags/tag", tag: tag
    end
  end

  f.nest(:linked_object) do
    case item.linked_object_type
    when "Donation"                     then json.partial! "api/v5/transactions/donation",       donation: linked
    when "AchTransfer"                  then json.partial! "api/v5/transactions/ach_transfer",   ach_transfer: linked
    when "Invoice"                      then json.partial! "api/v5/transactions/invoice",        invoice: linked
    when "Check", "IncreaseCheck"       then json.partial! "api/v5/transactions/check",          check: linked
    when "CheckDeposit"                 then json.partial! "api/v5/transactions/check_deposit",  check_deposit: linked
    when "WiseTransfer"                 then json.partial! "api/v5/transactions/wise_transfer",  wise_transfer: linked
    when "Wire"                         then json.partial! "api/v5/transactions/wire_transfer",  wire_transfer: linked
    when "Reimbursement::ExpensePayout" then json.partial! "api/v5/transactions/expense_payout", expense_payout: linked
    when "Disbursement::Outgoing", "Disbursement::Incoming"
      json.partial! "api/v5/transactions/disbursement", disbursement: linked.disbursement
    else
      json.nil!
    end
  end

  expand_association(f, json, :organization, item.primary_ledger&.event, partial: "api/v5/events/event", as: :event)
end
