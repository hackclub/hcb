class AddAasmStateDocument < ActiveRecord::Migration[7.0]
  def change
    add_column :documents, :aasm_state, :string
  end
end
