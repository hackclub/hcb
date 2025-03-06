class AddGSuiteRevocationImmunity < ActiveRecord::Migration[7.2]
  def change
    add_column :g_suites, :revocation_immunity, :boolean, default: false, null: false
  end
end
