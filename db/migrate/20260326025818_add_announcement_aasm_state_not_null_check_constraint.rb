class AddAnnouncementAasmStateNotNullCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :announcements, "aasm_state IS NOT NULL", name: "announcements_aasm_state_null", validate: false
  end
end
