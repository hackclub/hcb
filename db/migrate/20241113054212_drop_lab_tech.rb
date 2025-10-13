class DropLabTech < ActiveRecord::Migration[7.2]
  def change
    drop_table :lab_tech_experiments
    drop_table :lab_tech_observations
    drop_table :lab_tech_results
  end
end
