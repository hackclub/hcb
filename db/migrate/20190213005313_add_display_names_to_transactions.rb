# frozen_string_literal: true

class AddDisplayNamesToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transact_so_ns, :display_name, :text

    reversible do |dir|
      dir.up { TransactSON.find_each(&:set_default_display_name) }
    end
  end

end
