# frozen_string_literal: true

# Organizers can drag their tags into an order on the tags settings page. Tags
# that have never been reordered keep nil and sort after the positioned ones,
# in creation order, so nothing moves until someone drags something.
class AddSortIndexToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :sort_index, :integer
  end

end
