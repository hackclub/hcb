class AllowNullForPayeeLegalEntity < ActiveRecord::Migration[8.0]
  def change
    change_column_null :payees, :legal_entity_id, true
  end
end
