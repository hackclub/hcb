class DropOrganizerPositionContracts < ActiveRecord::Migration[8.0]
  def change
    drop_table :organizer_position_contracts do |t|
      t.string "aasm_state"
      t.string "cosigner_email"
      t.datetime "created_at", null: false
      t.datetime "deleted_at"
      t.bigint "document_id"
      t.string "external_id"
      t.integer "external_service"
      t.boolean "include_videos", default: false, null: false
      t.bigint "organizer_position_invite_id", null: false
      t.integer "purpose", default: 0
      t.datetime "signed_at"
      t.datetime "updated_at", null: false
      t.datetime "void_at"
      
      t.index ["document_id"], name: "index_organizer_position_contracts_on_document_id"
      t.index ["organizer_position_invite_id"], name: "idx_on_organizer_position_invite_id_ab1516f568"
    end
  end
end
