class AddUniqueIndexToRafflesOnProgramAndUserId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :raffles, [:program, :user_id], unique: true, algorithm: :concurrently
  end
end
