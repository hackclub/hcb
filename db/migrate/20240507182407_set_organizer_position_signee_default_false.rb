class SetOrganizerPositionSigneeDefaultFalse < ActiveRecord::Migration[7.0]
  def up
    # Change default value to false
    change_column_default :organizer_positions, :is_signee, false
    change_column_default :organizer_position_invites, :is_signee, false
  end
  
  def down
    # Revert default value
    change_column_default :organizer_positions, :is_signee, nil
    change_column_default :organizer_position_invites, :is_signee, nil
  end
end
