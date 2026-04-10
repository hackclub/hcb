# frozen_string_literal: true

json_object(json, paypal_transfer)
json.status paypal_transfer.aasm_state
json.recipient_name paypal_transfer.recipient_name
json.recipient_email paypal_transfer.recipient_email
json.payment_for paypal_transfer.payment_for
json.amount_cents paypal_transfer.amount_cents
