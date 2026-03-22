class CreateCardGrantPreAuthorizations < ActiveRecord::Migration[7.2]
  def change
    create_table :card_grant_pre_authorizations do |t|
      t.references :card_grant, null: false, foreign_key: true
      t.string :product_url
      t.string :aasm_state, null: false

      t.timestamps
    end
  end
end
