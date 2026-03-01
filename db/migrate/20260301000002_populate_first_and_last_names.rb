class PopulateFirstAndLastNames < ActiveRecord::Migration[8.0]
  def up
    require 'namae'

    User.find_each do |user|
      next if user.full_name.blank?

      namae = Namae.parse(user.full_name).first

      first_name_value = (namae&.given || namae&.particle)&.split(" ")&.first
      last_name_value = namae&.family&.split(" ")&.last

      user.update_columns(first_name: first_name_value, last_name: last_name_value)
    end
  end

  def down
    User.update_all(first_name: nil, last_name: nil)
  end
end
