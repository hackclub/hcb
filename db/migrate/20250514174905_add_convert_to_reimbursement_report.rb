class AddConvertToReimbursementReport < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grant_settings, :reimbursement_conversions_enabled, :boolean, default: true, null: false
  end
end
