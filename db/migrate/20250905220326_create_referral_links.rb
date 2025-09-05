class CreateReferralLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :referral_links do |t|
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :alias

      t.timestamps
    end

    add_index :referral_links, :alias, unique: true
  end
end
