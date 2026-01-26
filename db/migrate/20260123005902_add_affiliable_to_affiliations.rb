class AddAffiliableToAffiliations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_reference :event_affiliations, :affiliable, polymorphic: true, index: { algorithm: :concurrently }

    Event::Affiliation.all.each do |affiliation|
      affiliation.update!(affiliable: affiliation.event)
    end

    add_check_constraint :event_affiliations, "affiliable_type IS NOT NULL", name: "event_affiliations_affiliable_type_null", validate: false
    add_check_constraint :event_affiliations, "affiliable_id IS NOT NULL", name: "event_affiliations_affiliable_id_null", validate: false
  end

  def down
    Event::Affiliation.all.each do |affiliation|
      affiliation.update!(event: affiliation.affiliable)
    end

    remove_reference :event_affiliations, :affiliable, polymorphic: true
  end
end
