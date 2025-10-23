# frozen_string_literal: true

class AddDeletedAtToComments < ActiveRecord::Migration[7.1]
  def change
    add_column :comments, :deleted_at, :datetime
  end

end
