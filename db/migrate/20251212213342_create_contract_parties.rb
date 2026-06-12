class CreateContractParties < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_parties do |t|
      t.references :user
      t.references :contract, null: false
      t.string :role, null: false
      t.string :external_email
      t.string :aasm_state

      t.datetime :signed_at
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
