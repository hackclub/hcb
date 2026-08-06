# frozen_string_literal: true

class AddUniqueIndexToHcbCodePinsOnHcbCodeId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :hcb_code_pins, :hcb_code_id, algorithm: :concurrently

    add_index :hcb_code_pins, :hcb_code_id, unique: true, algorithm: :concurrently
  end

end
