class AddExternalFieldsToOpContract < ActiveRecord::Migration[7.1]
  def change
    add_column :organizer_position_contracts, :external_service, :integer
    add_column :organizer_position_contracts, :external_id, :string
  end
end
