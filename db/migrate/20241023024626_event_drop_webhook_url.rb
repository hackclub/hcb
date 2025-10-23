class EventDropWebhookUrl < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :webhook_url, :string
    end
  end
end
