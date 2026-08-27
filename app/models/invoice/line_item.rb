# frozen_string_literal: true

# == Schema Information
#
# Table name: invoice_line_items
#
#  id             :bigint           not null, primary key
#  amount         :bigint           not null
#  description    :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  invoice_id     :bigint           not null
#  item_stripe_id :text
#
# Indexes
#
#  index_invoice_line_items_on_invoice_id      (invoice_id)
#  index_invoice_line_items_on_item_stripe_id  (item_stripe_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#
class Invoice
  class LineItem < ApplicationRecord
    self.table_name = "invoice_line_items"

    belongs_to :invoice, inverse_of: :line_items

    validates_presence_of :description, :amount
    validates :amount, numericality: { greater_than_or_equal_to: 100, message: "must be at least $1" }
  end

end
