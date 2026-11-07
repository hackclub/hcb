# frozen_string_literal: true

# Splits every existing `users.full_name` into `first_name` / `last_name`.
# Rows that already have a first name are skipped, so this is safe to re-run.
class BackfillUserFirstAndLastNames < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  class MigrationUser < ApplicationRecord
    self.table_name = "users"

  end

  def up
    MigrationUser.where(first_name: nil).where.not(full_name: [nil, ""]).in_batches(of: BATCH_SIZE) do |batch|
      rows = batch.pluck(:id, :full_name).filter_map do |id, full_name|
        parsed = UserService::ParseName.new(full_name:).run
        next if parsed.first_name.blank?

        [id, parsed.first_name, parsed.last_name]
      end
      next if rows.empty?

      values = rows.map { |row| MigrationUser.sanitize_sql_array(["(?, ?, ?)", *row]) }.join(", ")
      MigrationUser.connection.execute(<<~SQL.squish)
        UPDATE users
        SET first_name = parsed.first_name, last_name = parsed.last_name
        FROM (VALUES #{values}) AS parsed(id, first_name, last_name)
        WHERE users.id = parsed.id
      SQL
    end
  end

  def down
    # The columns are dropped by the previous migration; nothing to undo here.
  end

end
