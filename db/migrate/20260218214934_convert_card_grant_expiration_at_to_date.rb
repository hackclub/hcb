class ConvertCardGrantExpirationAtToDate < ActiveRecord::Migration[8.0]
  def up
    safety_assured {
      execute <<-SQL
        ALTER TABLE card_grants
        ALTER COLUMN expiration_at TYPE DATE
        USING CAST(expiration_at AS DATE);
      SQL
    }
  end

  def down
    safety_assured {
      execute <<-SQL
        ALTER TABLE card_grants
        ALTER COLUMN expiration_at TYPE TIMESTAMP
        USING CAST(expiration_at AS TIMESTAMP);
      SQL
    }
  end
end
