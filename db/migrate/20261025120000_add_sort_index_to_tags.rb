# frozen_string_literal: true

class AddSortIndexToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :sort_index, :integer
  end

end
