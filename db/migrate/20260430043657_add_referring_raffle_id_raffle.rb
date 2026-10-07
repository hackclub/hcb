class AddReferringRaffleIdRaffle < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :raffles, :referring_raffle, index: {algorithm: :concurrently}
  end
end
