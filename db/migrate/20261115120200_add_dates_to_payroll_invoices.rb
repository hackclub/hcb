# frozen_string_literal: true

class AddDatesToPayrollInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_invoices, :start_date, :date
    add_column :payroll_invoices, :end_date, :date
  end

end
