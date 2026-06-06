# frozen_string_literal: true

class AddSendEmailNotificationToWires < ActiveRecord::Migration[7.2]
  def change
    add_column :wires, :send_email_notification, :boolean, default: false
  end
end
