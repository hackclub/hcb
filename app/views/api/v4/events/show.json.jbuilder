# frozen_string_literal: true

expand :balance_cents, :users, :account_number do
  json.partial! @event
end
