class PopulateFirstAndLastNames < ActiveRecord::Migration[8.0]
  BATCH_SIZE = 500

  def up
    require "namae"

    updates = []

    User.where.not(full_name: nil).select(:id, :full_name).find_each do |user|
      namae = Namae.parse(user.full_name).first
      updates << {
        id: user.id,
        first_name: (namae&.given || namae&.particle)&.split(" ")&.first,
        last_name: namae&.family&.split(" ")&.last,
      }

      if updates.size >= BATCH_SIZE
        User.upsert_all(updates, update_only: [:first_name, :last_name], unique_by: :id)
        updates.clear
      end
    end

    User.upsert_all(updates, update_only: [:first_name, :last_name], unique_by: :id) if updates.any?
  end

  def down
    User.update_all(first_name: nil, last_name: nil)
  end
end
