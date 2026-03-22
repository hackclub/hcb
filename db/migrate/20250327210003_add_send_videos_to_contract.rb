class AddSendVideosToContract < ActiveRecord::Migration[7.2]
  def change
    add_column :organizer_position_contracts, :include_videos, :boolean, null: false, default: false
  end
end
