# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_invoice_transactions
#
#  id                     :bigint           not null, primary key
#  amount_cents           :integer
#  date_posted            :date
#  state                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invoice_transaction_id :string
#
class RawPendingInvoiceTransaction < ApplicationRecord
  monetize :amount_cents

  def date
    date_posted
  end

  def memo
    "Invoice"
  end

  def likely_event_id
    @likely_event_id ||= invoice.event.id
  end

  def invoice
    @invoice ||= ::Invoice.find_by(id: invoice_transaction_id)
  end

end
