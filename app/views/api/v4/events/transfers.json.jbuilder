# frozen_string_literal: true

json.stats do
  json.deposited_cents @stats[:deposited]
  json.in_transit_cents @stats[:in_transit]
  json.canceled_cents @stats[:canceled]
end

pagination_metadata(json)

json.data @transfers do |transfer|
  json_object(json, transfer)

  case transfer
  when AchTransfer
    json.ach_transfer { json.partial! "api/v4/transactions/ach_transfer", ach_transfer: transfer }
  when IncreaseCheck, Check
    json.check { json.partial! "api/v4/transactions/check", check: transfer }
  when Disbursement
    json.disbursement { json.partial! "api/v4/transactions/disbursement", disbursement: transfer }
  when PaypalTransfer
    json.paypal_transfer { json.partial! "api/v4/transactions/paypal_transfer", paypal_transfer: transfer }
  when Wire
    json.wire { json.partial! "api/v4/transactions/wire", wire: transfer }
  when WiseTransfer
    json.wise_transfer { json.partial! "api/v4/transactions/wise_transfer", wise_transfer: transfer }
  end
end
