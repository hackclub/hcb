# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261116120000_create_tag_lists")

RSpec.describe CreateTagLists do
  # The migration builds indexes concurrently, which Postgres refuses inside a
  # transaction. It works in a schema of its own, so nothing leaks between tests.
  self.use_transactional_tests = false

  it "gives each event's ledger a list, shares it with the event's card grant ledgers, and moves tags onto it" do
    connection = ActiveRecord::Base.connection
    original_search_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA tag_lists_migration_test")
    connection.schema_search_path = "tag_lists_migration_test"

    connection.create_table(:card_grants) { |t| t.bigint :event_id, null: false }
    connection.create_table(:ledgers) do |t|
      t.boolean :primary, null: false
      t.bigint :event_id
      t.bigint :card_grant_id
    end
    connection.create_table(:tags) do |t|
      t.bigint :event_id, null: false
      t.text :label
    end
    connection.execute <<~SQL
      INSERT INTO card_grants (id, event_id) VALUES (1, 101), (2, 101);
      INSERT INTO ledgers (id, "primary", event_id, card_grant_id)
      VALUES (11, true, 101, NULL), (12, true, 102, NULL), (13, true, NULL, 1), (14, true, NULL, 2), (15, false, NULL, NULL);
      INSERT INTO tags (id, event_id, label) VALUES (21, 101, 'Snacks'), (22, 101, 'Venue'), (23, 102, 'Snacks');
    SQL

    migration = described_class.new
    migration.migrate(:up)

    expect(connection.select_rows("SELECT id, tag_list_id FROM ledgers ORDER BY id")).to eq([[11, 11], [12, 12], [13, 11], [14, 11], [15, nil]])
    expect(connection.select_rows("SELECT id, tag_list_id FROM tags ORDER BY id")).to eq([[21, 11], [22, 11], [23, 12]])
    expect(connection.select_value("SELECT COUNT(*) FROM tag_lists").to_i).to eq(2)
    # New lists take ids after the ones the ledgers lent.
    expect(connection.select_value("INSERT INTO tag_lists (created_at, updated_at) VALUES (NOW(), NOW()) RETURNING id").to_i).to eq(13)
    expect(connection.columns(:tags).find { |c| c.name == "tag_list_id" }.null).to be(false)
    expect(connection.columns(:tags).find { |c| c.name == "event_id" }.null).to be(true)

    connection.execute("UPDATE tags SET event_id = NULL")
    migration.migrate(:down)

    expect(connection.select_rows("SELECT id, event_id FROM tags ORDER BY id")).to eq([[21, 101], [22, 101], [23, 102]])
    expect(connection.column_exists?(:tags, :tag_list_id)).to be(false)
    expect(connection.column_exists?(:ledgers, :tag_list_id)).to be(false)
    expect(connection.table_exists?(:tag_lists)).to be(false)
  ensure
    connection.schema_search_path = original_search_path
    connection.execute("DROP SCHEMA IF EXISTS tag_lists_migration_test CASCADE")
    connection.schema_cache.clear!
  end
end
