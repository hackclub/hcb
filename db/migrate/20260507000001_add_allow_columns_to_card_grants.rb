# frozen_string_literal: true

class AddAllowColumnsToCardGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grants, :allow_stripe_card, :boolean, default: true, null: false
    add_column :card_grants, :allow_reimbursement_report, :boolean, default: false, null: false
  end
end
