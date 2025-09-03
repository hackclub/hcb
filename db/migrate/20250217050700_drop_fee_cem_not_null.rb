class DropFeeCemNotNull < ActiveRecord::Migration[7.2]
  def change
    change_column_null :fees, :canonical_event_mapping_id, true
  end
end
