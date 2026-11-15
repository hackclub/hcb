class AddSignedOutAtToSession < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :signed_out_at, :datetime
  end
end
