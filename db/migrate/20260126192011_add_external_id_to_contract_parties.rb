class AddExternalIdToContractParties < ActiveRecord::Migration[8.0]
  def change
    add_column :contract_parties, :external_id, :string
  end
end
