# frozen_string_literal: true

class AddReviewNoteToPayrollInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_invoices, :review_note, :text
  end

end
