class ConvertCardGrantExpirationAtToDate < ActiveRecord::Migration[8.0]
  def change
    safety_assured {
      change_column :card_grants, :expiration_at, :date
    }
  end
end
