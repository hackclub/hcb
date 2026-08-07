class AddTicketNumberToRaffle < ActiveRecord::Migration[8.0]
  def change
    add_column :raffles, :ticket_number, :string, null: true
  end
end
