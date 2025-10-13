class WireAddFailureReasonField < ActiveRecord::Migration[7.2]
  def change
    add_column :wires, :return_reason, :text
  end
end
