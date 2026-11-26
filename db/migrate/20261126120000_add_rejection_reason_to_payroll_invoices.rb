# frozen_string_literal: true

class AddRejectionReasonToPayrollInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_invoices, :rejection_reason, :text
  end

end
