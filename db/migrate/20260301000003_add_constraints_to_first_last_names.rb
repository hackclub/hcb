class AddConstraintsToFirstLastNames < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :users, "first_name IS NOT NULL", name: "users_first_name_not_null", validate: false
    # Note: last_name can be NULL to support single-name users
  end
end
