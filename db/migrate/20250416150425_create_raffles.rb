class CreateRaffles < ActiveRecord::Migration[7.2]
  def change
    create_table :raffles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :program, null: false

      t.timestamps
    end
  end
end
