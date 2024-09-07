class AddFeeCoveredToDonation < ActiveRecord::Migration[7.1]
  def change
    add_column :donations, :fee_covered, :boolean, default: false, null: false
  end
end
