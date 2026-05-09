# frozen_string_literal: true

class AddAllowColumnsToCardGrantSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :card_grant_settings, :allow_stripe_card, :boolean, default: true, null: false
    add_column :card_grant_settings, :allow_reimbursement_report, :boolean, default: false, null: false
  end
end
