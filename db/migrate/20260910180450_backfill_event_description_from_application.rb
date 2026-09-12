# frozen_string_literal: true

class BackfillEventDescriptionFromApplication < ActiveRecord::Migration[8.1]
  def up
    Event.joins(:application)
         .where(events: { description: [nil, ""] })
         .where.not(event_applications: { description: [nil, ""] })
         .find_each do |event|
      event.update_column(:description, event.application.description)
    end
  end

  def down
    # No-op; the mission statements remain populated.
  end
end