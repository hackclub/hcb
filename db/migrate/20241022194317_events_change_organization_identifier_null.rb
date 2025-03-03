# frozen_string_literal: true

class EventsChangeOrganizationIdentifierNull < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      change_column_null :events, :organization_identifier, true
    end
  end
end
