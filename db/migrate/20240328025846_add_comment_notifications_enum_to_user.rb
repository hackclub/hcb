class AddCommentNotificationsEnumToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :comment_notifications, :integer, null: false, default: 0
  end
end

