class CreateReferralAttributions < ActiveRecord::Migration[7.2]
  def change
    create_table :referral_attributions do |t|
      t.references :referral_program, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
