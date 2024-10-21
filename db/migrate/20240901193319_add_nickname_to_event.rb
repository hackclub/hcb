class AddNicknameToEvent < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :short_name, :string
  end
end
