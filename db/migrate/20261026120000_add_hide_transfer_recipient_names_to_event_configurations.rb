# frozen_string_literal: true

class AddHideTransferRecipientNamesToEventConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_configurations, :hide_transfer_recipient_names, :boolean, null: false, default: false
  end
end
