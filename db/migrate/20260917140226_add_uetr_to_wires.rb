# frozen_string_literal: true

class AddUetrToWires < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationWire < ActiveRecord::Base
    self.table_name = "wires"

  end

  def up
    add_column :wires, :uetr, :string

    MigrationWire.reset_column_information

    MigrationWire.where.not(column_id: nil).where(uetr: nil).find_each do |wire|
      uetr = ColumnService.international_wire(wire.column_id)["uetr"]

      wire.update_column(:uetr, uetr) if uetr.present?
    rescue Faraday::Error => e
      say "Skipping wire #{wire.id}: #{e.message}"
    end
  end

  def down
    remove_column :wires, :uetr
  end

end
