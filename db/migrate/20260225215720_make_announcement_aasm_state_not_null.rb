class MakeAnnouncementAasmStateNotNull < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      change_column_null :announcements, :aasm_state, false
    end
  end
  def down
    change_column_null :announcements, :aasm_state, true
  end
end
