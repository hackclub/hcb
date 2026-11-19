# frozen_string_literal: true

class DropTransactionCsvs < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      drop_table :transaction_csvs do |t|
        t.string :aasm_state, null: false

        t.timestamps
      end
    end
  end

end
