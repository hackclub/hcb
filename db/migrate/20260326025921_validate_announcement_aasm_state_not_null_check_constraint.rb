class ValidateAnnouncementAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :announcements, name: "announcements_aasm_state_null"
    change_column_null :announcements, :aasm_state, false
    remove_check_constraint :announcements, name: "announcements_aasm_state_null"
  end

  def down
    add_check_constraint :announcements, "aasm_state IS NOT NULL", name: "announcements_aasm_state_null", validate: false
    change_column_null :announcements, :aasm_state, true
  end
end
