# frozen_string_literal: true

class AddAllowColumnsToCardGrants < ActiveRecord::Migration[7.2]
  def up
    add_column :card_grants, :allow_stripe_card, :boolean, default: true, null: false
    add_column :card_grants, :allow_reimbursement_report, :boolean

    safety_assured do
      execute <<~SQL
        UPDATE card_grants
        SET allow_reimbursement_report = card_grant_settings.reimbursement_conversions_enabled
        FROM card_grant_settings
        WHERE card_grant_settings.event_id = card_grants.event_id
      SQL

      execute <<~SQL
        UPDATE card_grants SET allow_reimbursement_report = false WHERE allow_reimbursement_report IS NULL
      SQL

      change_column_null :card_grants, :allow_reimbursement_report, false
    end

    change_column_default :card_grants, :allow_reimbursement_report, false
  end

  def down
    remove_column :card_grants, :allow_stripe_card
    remove_column :card_grants, :allow_reimbursement_report
  end
end
