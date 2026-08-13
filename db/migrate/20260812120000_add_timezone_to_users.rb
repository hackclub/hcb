# frozen_string_literal: true

class AddTimezoneToUsers < ActiveRecord::Migration[8.1]
  def change
    # Nullable on purpose: NULL means the user has never picked a timezone, which
    # has to stay distinguishable from them explicitly picking the default one.
    add_column :users, :timezone, :string
  end

end
