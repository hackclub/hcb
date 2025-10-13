# frozen_string_literal: true

class AddNullCheckConstraintToEventsName < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint(
      :events,
      "name IS NOT NULL",
      name: "events_name_not_null",
      validate: false
    )
  end
end
