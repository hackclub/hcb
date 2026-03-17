class ConvertCardGrantExpirationAtToDate < ActiveRecord::Migration[8.0]
  def up
    safety_assured {
      change_column :card_grants, :expiration_at, :date
    }
  end

  def down
    safety_assured {
      change_column :card_grants, :expiration_at, :datetime
    }
  end
end
