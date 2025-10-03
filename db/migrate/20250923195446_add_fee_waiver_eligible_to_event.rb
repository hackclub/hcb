class AddFeeWaiverEligibleToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :fee_waiver_eligible, :boolean, default: false, null: false
  end
end
