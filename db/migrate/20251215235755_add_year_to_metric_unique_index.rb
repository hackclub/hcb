class AddYearToMetricUniqueIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index(:metrics, [:subject_type, :subject_id, :type, :year], unique: true, algorithm: :concurrently)

    remove_index(:metrics, [:subject_type, :subject_id, :type], unique: true)
  end
end
