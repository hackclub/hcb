# frozen_string_literal: true

class AddDisbursements < ActiveRecord::Migration[7.0]
  def change
    add_column :disbursements, :scheduled_on, :date
  end

end
