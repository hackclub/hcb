class AddLastExpiryNotificationSentAtToCardGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :last_expiry_notification_sent_at, :datetime
  end
end
