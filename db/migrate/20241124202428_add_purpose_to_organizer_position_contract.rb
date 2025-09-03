class AddPurposeToOrganizerPositionContract < ActiveRecord::Migration[7.2]
  def change
    add_column :organizer_position_contracts, :purpose, :integer, default: 0
  end
end
