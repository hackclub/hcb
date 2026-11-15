class AddGSuiteRevocationImmunity < ActiveRecord::Migration[7.2]
  def change
    add_column :g_suites, :immune_to_revocation, :boolean, default: false, null: false
  end
end
