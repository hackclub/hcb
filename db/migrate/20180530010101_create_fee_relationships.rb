# frozen_string_literal: true

class CreateFeeRelationships < ActiveRecord::Migration[5.2]
  def change
    create_table :fee_relationships do |t|
      t.references :event, foreign_key: true
      t.references :transact_son, foreign_key: true
      t.boolean :fee_applies
      t.bigint :fee_amount
      t.boolean :is_fee_payment

      t.timestamps
    end
  end

end
