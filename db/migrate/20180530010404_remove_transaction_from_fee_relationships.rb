# frozen_string_literal: true

class RemoveTransactionFromFeeRelationships < ActiveRecord::Migration[5.2]
  def change
    remove_reference :fee_relationships, :transact_son, foreign_key: true
  end

end
