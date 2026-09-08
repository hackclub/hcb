# frozen_string_literal: true

class AddNameToLegalEntityPayoutMethods < ActiveRecord::Migration[8.0]
  def change
    add_column :legal_entity_payout_methods, :name, :string
  end

end
