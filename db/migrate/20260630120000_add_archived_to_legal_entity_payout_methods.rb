class AddArchivedToLegalEntityPayoutMethods < ActiveRecord::Migration[8.0]
  def change
    add_column :legal_entity_payout_methods, :archived, :boolean, null: false, default: false
  end
end
