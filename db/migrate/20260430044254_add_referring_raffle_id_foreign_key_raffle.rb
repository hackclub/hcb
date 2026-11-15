class AddReferringRaffleIdForeignKeyRaffle < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :raffles, :raffles, column: :referring_raffle_id, validate: false
  end
end
