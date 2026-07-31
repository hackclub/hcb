# frozen_string_literal: true

class AddImportedAtToPayees < ActiveRecord::Migration[8.0]
  def change
    add_column :payees, :imported_at, :datetime
  end

end
