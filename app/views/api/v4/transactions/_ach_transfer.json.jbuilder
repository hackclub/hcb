# frozen_string_literal: true

json.recipient_name ach_transfer.recipient_name
json.recipient_email ach_transfer.recipient_email
json.bank_name ach_transfer.bank_name

if policy(ach_transfer).view_account_routing_numbers?
  json.account_number_last4 ach_transfer.account_number.slice(-4, 4)
  json.routing_number ach_transfer.routing_number
end

json.payment_for ach_transfer.payment_for
json.sender do
  if ach_transfer.creator.present?
    json.partial! "api/v4/users/user", user: ach_transfer.creator
  else
    json.nil!
  end
end
