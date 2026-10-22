class AddConfirmedToRaffles < ActiveRecord::Migration[8.0]
  def change
    add_column :raffles, :confirmed, :boolean, null: false, default: true
  end
end
