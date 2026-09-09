# frozen_string_literal: true

# locals: (json:, ach_transfer:)

object_shape(json, ach_transfer) do |f|
  f.amount_cents ach_transfer.amount
  f.date ach_transfer.created_at
  f.status ach_transfer.aasm_state
  f.recipient_name ach_transfer.recipient_name
  f.recipient_email ach_transfer.recipient_email
  f.bank_name ach_transfer.bank_name
  f.payment_for ach_transfer.payment_for
  f.routing_number ach_transfer.routing_number

  # Block form: the account number is an encrypted column, so a viewer who
  # can't see this field never pays to decrypt it.
  f.account_number_last4 { ach_transfer.account_number.slice(-4, 4) }

  f.nest(:sender) do
    if ach_transfer.creator.present?
      json.partial! "api/v5/users/user", user: ach_transfer.creator
    else
      json.nil!
    end
  end
end
