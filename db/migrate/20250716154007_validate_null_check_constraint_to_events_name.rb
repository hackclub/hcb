# frozen_string_literal: true

class ValidateNullCheckConstraintToEventsName < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint(:events, name: "events_name_not_null")
    change_column_null(:events, :name, false)
    remove_check_constraint(:events, name: "events_name_not_null")
  end

  def down
    add_check_constraint(
      :events,
      "name IS NOT NULL",
      name: "events_name_not_null",
      validate: false
    )
    change_column_null(:events, :name, true)
  end
end
