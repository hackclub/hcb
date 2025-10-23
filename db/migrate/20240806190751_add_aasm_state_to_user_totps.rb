class AddAasmStateToUserTotps < ActiveRecord::Migration[7.1]
  def change
    add_column :user_totps, :aasm_state, :string
  end
end
