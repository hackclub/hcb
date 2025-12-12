class CreateContractParties < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_parties do |t|
      t.references :user
      t.references :contract, null: false
      t.integer :role, null: false
      t.string :external_email

      t.timestamps
    end
  end
end
