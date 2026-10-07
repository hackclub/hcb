class DropDemoModeRequestMeetingAtFromEvents < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :events, :demo_mode_request_meeting_at, :datetime }
  end
end
