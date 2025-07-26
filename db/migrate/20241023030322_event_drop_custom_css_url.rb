class EventDropCustomCssUrl < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      remove_column :events, :custom_css_url, :string
    end
  end
end
