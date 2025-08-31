class MakeEventIdOnCardGrantSettingNullable < ActiveRecord::Migration[7.2]
  def up
    change_column_null :card_grant_settings, :event_id, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "this migration cannot be reversed because event id may be null"
  end
end
