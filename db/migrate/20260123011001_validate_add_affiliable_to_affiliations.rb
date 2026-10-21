class ValidateAddAffiliableToAffiliations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  
  def up
    validate_check_constraint :event_affiliations, name: "event_affiliations_affiliable_type_null"
    change_column_null :event_affiliations, :affiliable_type, false
    remove_check_constraint :event_affiliations, name: "event_affiliations_affiliable_type_null"

    validate_check_constraint :event_affiliations, name: "event_affiliations_affiliable_id_null"
    change_column_null :event_affiliations, :affiliable_id, false
    remove_check_constraint :event_affiliations, name: "event_affiliations_affiliable_id_null"
  end

  def down
    add_check_constraint :event_affiliations, "affiliable_type IS NOT NULL", name: "event_affiliations_affiliable_type_null", validate: false
    change_column_null :event_affiliations, :affiliable_type, true

    add_check_constraint :event_affiliations, "affiliable_id IS NOT NULL", name: "event_affiliations_affiliable_id_null", validate: false
    change_column_null :event_affiliations, :affiliable_id, true
  end
end
