class AddUniqueIndexToMetric < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_index(:metrics, [:subject_type, :subject_id, :type], unique: true, algorithm: :concurrently)
  end
end
