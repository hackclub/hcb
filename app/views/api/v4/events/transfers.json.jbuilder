# frozen_string_literal: true

if expand?(:stats)
  json.stats do
    json.deposited_cents @stats[:deposited]
    json.in_transit_cents @stats[:in_transit]
    json.canceled_cents @stats[:canceled]
  end
end

pagination_metadata(json)

json.data @transfers do |transfer|
  case transfer
  when AchTransfer
    json.partial! "api/v4/transactions/ach_transfer", ach_transfer: transfer
  when IncreaseCheck, Check
    json.partial! "api/v4/transactions/check", check: transfer
  when Disbursement
    json.partial! "api/v4/transactions/disbursement", disbursement: transfer
  when PaypalTransfer
    json.partial! "api/v4/transactions/paypal_transfer", paypal_transfer: transfer
  when Wire
    json.partial! "api/v4/transactions/wire", wire: transfer
  when WiseTransfer
    json.partial! "api/v4/transactions/wise_transfer", wise_transfer: transfer
  end
end
