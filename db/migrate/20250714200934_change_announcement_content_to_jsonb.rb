class ChangeAnnouncementContentToJsonb < ActiveRecord::Migration[7.2]
  # === Dangerous operation detected #strong_migrations ===
  #
  # Changing the type of an existing column blocks reads and writes
  # while the entire table is rewritten. A safer approach is to:
  #
  # 1. Create a new column
  # 2. Write to both columns
  # 3. Backfill data from the old column to the new column
  # 4. Move reads from the old column to the new column
  # 5. Stop writing to the old column
  # 6. Drop the old column

  # This is bad, but I'm intentionally choosing to skip the proper renaming
  # process outlined above in favor of just doing a simple `change_column` to
  # update the type from text to jsonb. The values inside the column are already
  # JSON and this table is low traffic, so the risk of downtime is minimal (or
  # so I hope).
  # — @garyhtou

  def up
    safety_assured do
      change_column :announcements, :content, :jsonb, null: false, using: 'CAST(content AS JSON)'
    end
  end

  def down
    safety_assured do
      change_column :announcements, :content, :text
    end
  end
end
