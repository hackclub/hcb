class CreateReferralLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :referral_links do |t|
      t.string :name
      t.references :referral_program, null: false, foreign_key: true

      t.timestamps
    end
  end
end
