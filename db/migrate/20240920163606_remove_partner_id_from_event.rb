class RemovePartnerIdFromEvent < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :partner_id
    end
  end
end
