class ValidateMakeMetadataAndNameNotNullOnEventAffiliations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    validate_check_constraint :event_affiliations, name: "event_affiliations_metadata_null"
    change_column_null :event_affiliations, :metadata, false
    remove_check_constraint :event_affiliations, name: "event_affiliations_metadata_null"

    validate_check_constraint :event_affiliations, name: "event_affiliations_name_null"
    change_column_null :event_affiliations, :name, false
    remove_check_constraint :event_affiliations, name: "event_affiliations_name_null"
  end

  def down
    add_check_constraint :event_affiliations, "metadata IS NOT NULL", name: "event_affiliations_metadata_null", validate: false
    change_column_null :event_affiliations, :metadata, true

    add_check_constraint :event_affiliations, "name IS NOT NULL", name: "event_affiliations_name_null", validate: false
    change_column_null :event_affiliations, :name, true
  end
end
