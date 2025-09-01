# frozen_string_literal: true

expand @event do
  json.array! @invoices, partial: "api/v4/invoices/invoice", as: :invoice
end
