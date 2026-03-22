class MakeMetadataAndNameNotNullOnEventAffiliations < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :event_affiliations, "metadata IS NOT NULL", name: "event_affiliations_metadata_null", validate: false
    add_check_constraint :event_affiliations, "name IS NOT NULL", name: "event_affiliations_name_null", validate: false
  end
end
