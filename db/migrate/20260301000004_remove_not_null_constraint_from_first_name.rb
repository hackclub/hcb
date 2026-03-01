class RemoveNotNullConstraintFromFirstName < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :users, name: "users_first_name_not_null"
  end
end
