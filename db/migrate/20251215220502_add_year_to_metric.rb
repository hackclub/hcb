class AddYearToMetric < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :year, :integer
  end
end
