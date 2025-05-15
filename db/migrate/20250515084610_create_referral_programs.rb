class CreateReferralPrograms < ActiveRecord::Migration[7.2]
  def change
    create_table :referral_programs do |t|
      t.string :name, null: false
      t.boolean :show_explore_hack_club, null: false, default: false

      t.timestamps
    end
  end
end
