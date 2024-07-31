class AddCompanyNameAndCompanyEntryDescription < ActiveRecord::Migration[7.0]
  def change
    add_column :ach_transfers, :company_name, :string
    add_column :ach_transfers, :company_entry_description, :string
  end
end
