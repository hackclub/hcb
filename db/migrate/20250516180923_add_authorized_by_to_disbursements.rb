class AddAuthorizedByToDisbursements < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :disbursements, :authorized_by,
                    null: true,
                    foreign_key: { to_table: :users },
                    index: { algorithm: :concurrently }
    end
  end
end
