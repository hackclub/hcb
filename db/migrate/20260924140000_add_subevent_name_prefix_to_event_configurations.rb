# frozen_string_literal: true

class AddSubeventNamePrefixToEventConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_configurations, :subevent_name_prefix, :string
  end

end
