# frozen_string_literal: true

class AddImportedAtToPayees < ActiveRecord::Migration[8.1]
  def change
    add_column :payees, :imported_at, :datetime
  end

end
