class AddUniqueIndexToRafflesOnProgramAndUserId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :raffles, name: :index_raffles_on_program_and_user_id, if_exists: true

    add_index :raffles, [:program, :user_id], unique: true, algorithm: :concurrently, name: :index_raffles_on_program_and_user_id
  end
end
