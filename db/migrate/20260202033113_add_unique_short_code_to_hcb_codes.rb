class AddUniqueShortCodeToHcbCodes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :hcb_codes, :short_code,
              unique: true,
              algorithm: :concurrently
  end
end
