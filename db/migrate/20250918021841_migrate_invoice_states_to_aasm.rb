class MigrateInvoiceStatesToAasm < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    Invoice.find_in_batches(batch_size: 100) do |batch|
      batch.each do |invoice|
        if invoice.deposited?
          invoice.update_column(:aasm_state, :deposited_v2)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
