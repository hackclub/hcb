class RemoveOwnersFromEvent < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :owner_phone
      remove_column :events, :owner_address
      remove_column :events, :owner_birthdate
      remove_column :events, :owner_email
      remove_column :events, :owner_name
    end
  end
end
