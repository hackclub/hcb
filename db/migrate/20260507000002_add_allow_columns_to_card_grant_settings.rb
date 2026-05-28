# frozen_string_literal: true

class AddAllowColumnsToCardGrantSettings < ActiveRecord::Migration[8.0]
  def up
    add_column :card_grant_settings, :allow_stripe_card, :boolean, default: true, null: false
    add_column :card_grant_settings, :allow_reimbursement_report, :boolean

    safety_assured do
      execute <<~SQL
        UPDATE card_grant_settings
        SET allow_reimbursement_report = reimbursement_conversions_enabled
      SQL

      change_column_null :card_grant_settings, :allow_reimbursement_report, false
    end

    change_column_default :card_grant_settings, :allow_reimbursement_report, false
  end

  def down
    remove_column :card_grant_settings, :allow_stripe_card
    remove_column :card_grant_settings, :allow_reimbursement_report
  end
end
