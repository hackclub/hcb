class AddUniqueIndexOnTicketNumberToRaffles < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :raffles, :ticket_number, unique: true, algorithm: :concurrently
  end
end
