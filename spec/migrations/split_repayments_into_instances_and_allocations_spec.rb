# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/migrate/20261110120000_split_repayments_into_instances_and_allocations")

RSpec.describe SplitRepaymentsIntoInstancesAndAllocations do
  it "groups allocations by disbursement and preserves expense amounts, snapshots and links through rollback" do
    connection = ActiveRecord::Base.connection
    original_search_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA repayment_migration_test")
    connection.schema_search_path = "repayment_migration_test"

    connection.create_table(:disbursements)
    connection.create_table(:ledger_items)
    connection.create_table(:repayments) do |t|
      t.references :disbursement, null: false, foreign_key: true
      t.references :ledger_item, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.jsonb :previous_categories, null: false, default: {}
      t.timestamps
    end
    connection.add_index(:repayments, [:disbursement_id, :ledger_item_id], unique: true)
    connection.execute <<~SQL
      INSERT INTO disbursements (id) VALUES (11), (12);
      INSERT INTO ledger_items (id) VALUES (21), (22);
      INSERT INTO repayments (id, disbursement_id, ledger_item_id, amount_cents, previous_categories, created_at, updated_at)
      VALUES (31, 11, 21, 10000, '{"CanonicalTransaction:1":{"slug":"food-fun","assignment_strategy":"automatic"}}', '2026-01-01', '2026-01-02'),
             (32, 11, 22, 2345, '{"CanonicalTransaction:2":null}', '2026-01-03', '2026-01-04'),
             (33, 12, 21, 10000, '{"CanonicalTransaction:1":{"slug":"venue","assignment_strategy":"manual"}}', '2026-02-01', '2026-02-02');
    SQL
    original_rows = connection.select_all("SELECT * FROM repayments ORDER BY id").to_a

    migration = described_class.new
    migration.migrate(:up)
    rows = connection.select_all(<<~SQL).to_a
      SELECT allocations.id, repayments.disbursement_id, allocations.ledger_item_id,
             allocations.amount_cents, allocations.previous_categories, allocations.created_at, allocations.updated_at
      FROM repayment_allocations allocations JOIN repayments ON repayments.id = allocations.repayment_id
      ORDER BY allocations.id
    SQL
    expect(rows).to eq(original_rows)
    expect(connection.select_value("SELECT COUNT(*) FROM repayments").to_i).to eq(2)
    expect(connection.select_rows("SELECT created_at::date::text, updated_at::date::text FROM repayments WHERE disbursement_id = 11")).to eq([["2026-01-01", "2026-01-04"]])
    expect(connection.indexes(:repayments)).to include(have_attributes(columns: ["disbursement_id"], unique: true))
    expect(connection.check_constraints(:repayment_allocations).map(&:name)).to include("repayment_allocations_positive_amount")

    migration.migrate(:down)
    expect(connection.select_all("SELECT * FROM repayments ORDER BY id").to_a).to eq(original_rows)
    migration.migrate(:up)
    expect(connection.select_value("SELECT SUM(amount_cents) FROM repayment_allocations").to_i).to eq(22345)
  ensure
    connection.schema_search_path = original_search_path
    connection.execute("DROP SCHEMA IF EXISTS repayment_migration_test CASCADE")
    connection.schema_cache.clear!
  end
end
