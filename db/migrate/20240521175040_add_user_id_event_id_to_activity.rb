class AddUserIdEventIdToActivity < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference :activities, :event, null: true, index: { algorithm: :concurrently }
  end
end
