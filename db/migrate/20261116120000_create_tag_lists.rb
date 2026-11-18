# frozen_string_literal: true

# Tags belonged to an event, but tags need to work for ledgers that no event
# owns (https://github.com/hackclub/hcb/issues/15708), so they move onto a tag
# list that a ledger points at. Backfilled in the same migration so that no
# deploy sees tags without a list: every tag would be unusable until it ran.
#
# tags.event_id stays (nullable and ignored by the model) until a follow-up
# drops it, so a rollback can put it back.
#
# Each step commits on its own, so they're safe to re-run after a lock timeout.
class CreateTagLists < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    create_table :tag_lists, if_not_exists: true do |t|
      t.timestamps
    end

    add_reference :ledgers, :tag_list, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true
    add_foreign_key :ledgers, :tag_lists, validate: false, if_not_exists: true
    validate_foreign_key :ledgers, :tag_lists

    add_reference :tags, :tag_list, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true
    add_foreign_key :tags, :tag_lists, validate: false, if_not_exists: true
    validate_foreign_key :tags, :tag_lists

    # One list per event-owned ledger. The list takes the ledger's id so the
    # two can be matched up afterwards without a temporary column. A card
    # grant's ledger shares its event's list, since the grant's charges are
    # tagged with the event's tags. Tags then follow their event's ledger.
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO tag_lists (id, created_at, updated_at)
        SELECT id, NOW(), NOW() FROM ledgers
        WHERE event_id IS NOT NULL AND tag_list_id IS NULL;

        UPDATE ledgers SET tag_list_id = id
        WHERE event_id IS NOT NULL AND tag_list_id IS NULL;

        SELECT setval('tag_lists_id_seq', GREATEST((SELECT MAX(id) FROM tag_lists), 1));

        UPDATE ledgers SET tag_list_id = event_ledgers.tag_list_id
        FROM card_grants, ledgers AS event_ledgers
        WHERE ledgers.card_grant_id = card_grants.id
          AND event_ledgers.event_id = card_grants.event_id
          AND ledgers.tag_list_id IS NULL;

        UPDATE tags SET tag_list_id = ledgers.tag_list_id
        FROM ledgers
        WHERE ledgers.event_id = tags.event_id AND tags.tag_list_id IS NULL;
      SQL
    end

    add_check_constraint :tags, "tag_list_id IS NOT NULL", name: "tags_tag_list_id_null", validate: false, if_not_exists: true
    validate_check_constraint :tags, name: "tags_tag_list_id_null"
    change_column_null :tags, :tag_list_id, false
    remove_check_constraint :tags, name: "tags_tag_list_id_null", if_exists: true

    change_column_null :tags, :event_id, true
  end

  def down
    safety_assured do
      execute <<~SQL.squish
        UPDATE tags SET event_id = ledgers.event_id
        FROM ledgers
        WHERE ledgers.tag_list_id = tags.tag_list_id AND ledgers.event_id IS NOT NULL AND tags.event_id IS NULL;
      SQL
    end

    if select_value("SELECT 1 FROM tags WHERE event_id IS NULL LIMIT 1")
      raise ActiveRecord::IrreversibleMigration, "tags on a list no event's ledger uses exist; remove them first"
    end

    change_column_null :tags, :event_id, false
    remove_reference :tags, :tag_list, foreign_key: true, index: true
    remove_reference :ledgers, :tag_list, foreign_key: true, index: true
    drop_table :tag_lists
  end

end
