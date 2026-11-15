class CreateContracts < ActiveRecord::Migration[8.0]
  def up
    create_table :contracts do |t|
      t.string :type, null: false
      t.string :aasm_state, null: false
      t.string :cosigner_email
      t.integer :external_service
      t.string :external_template_id
      t.boolean :include_videos
      t.string :external_id
      t.jsonb :prefills

      t.datetime :signed_at
      t.datetime :void_at
      t.timestamp :deleted_at

      t.references :contractable, polymorphic: true
      t.references :document, foreign_key: true

      t.timestamps
    end

    # migrate records from organizer_position_contracts
    OrganizerPosition::Contract.all.in_batches.each do |relation|
      new_rows = relation.map do |row|
        {
          id: row.id,
          aasm_state: row.aasm_state,
          cosigner_email: row.cosigner_email,
          external_service: row.external_service,
          include_videos: row.include_videos,
          external_id: row.external_id,
          signed_at: row.signed_at,
          void_at: row.void_at,
          deleted_at: row.deleted_at,
          contractable_id: row.organizer_position_invite_id,
          contractable_type: "OrganizerPositionInvite",
          document_id: row.document_id,
          type: "Contract::FiscalSponsorship",
        }
      end

      Contract.insert_all(new_rows)
    end

    # When we backfill the new contracts table with the old organizer position contracts,
    # we need to reset the primary key sequence so that any new contracts get a unique ID
    # instead of 1.
    ActiveRecord::Base.connection.reset_pk_sequence!('contracts')
    
    # rename papertrail item types
    PaperTrail::Version.where(item_type: "OrganizerPosition::Contract").update_all(item_type: "Contract::FiscalSponsorship")
  end

  def down
    drop_table :contracts
    PaperTrail::Version.where(item_type: "Contract").update_all(item_type: "OrganizerPosition::Contract")
  end
end
