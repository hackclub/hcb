# frozen_string_literal: true

class AddFeeRelationshipToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_reference :transact_so_ns, :fee_relationship, foreign_key: true
  end

end
