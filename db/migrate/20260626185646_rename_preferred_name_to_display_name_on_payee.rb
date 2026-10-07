class RenamePreferredNameToDisplayNameOnPayee < ActiveRecord::Migration[8.0]
  def change
    safety_assured { rename_column :payees, :preferred_name, :display_name }
  end
end
