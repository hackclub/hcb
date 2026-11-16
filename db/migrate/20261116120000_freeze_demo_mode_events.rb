# frozen_string_literal: true

class FreezeDemoModeEvents < ActiveRecord::Migration[8.1]
  def up
    # Keep demo restrictions until their removal is deployed. Include deleted
    # organizations so restoring one cannot bypass this backfill.
    safety_assured do
      execute <<~SQL
        UPDATE events
        SET financially_frozen = TRUE
        WHERE demo_mode = TRUE AND financially_frozen = FALSE
      SQL
    end
  end

  def down
    # Previously frozen organizations cannot be distinguished, so nothing is safe to undo.
  end

end
