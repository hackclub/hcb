class RemoveEventRequirementFromReport < ActiveRecord::Migration[7.1]
  def change
    change_column_null :reimbursement_reports, :event_id, true
  end
end
