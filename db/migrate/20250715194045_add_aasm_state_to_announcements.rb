class AddAasmStateToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :aasm_state, :string
  end
end
