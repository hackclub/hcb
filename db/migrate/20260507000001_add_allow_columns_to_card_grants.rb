# frozen_string_literal: true

class AddAllowColumnsToCardGrants < ActiveRecord::Migration[8.0]
  def up
    add_column :card_grants, :allow_stripe_card, :boolean, default: true, null: false
    add_column :card_grants, :allow_reimbursement_report, :boolean, default: false, null: false
  end

  def down
    remove_column :card_grants, :allow_stripe_card
    remove_column :card_grants, :allow_reimbursement_report
  end
end
