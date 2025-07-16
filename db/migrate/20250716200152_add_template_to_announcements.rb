class AddTemplateToAnnouncements < ActiveRecord::Migration[7.2]
  def change
    add_column :announcements, :template, :string
  end
end
