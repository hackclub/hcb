# frozen_string_literal: true

class AddAllowColumnsToCardGrants < ActiveRecord::Migration[8.0]
  def up
    # No database-level default: a newly built CardGrant must start as `nil` so
    # that `CardGrant#apply_acceptance_method_defaults` can inherit the value
    # from the event's CardGrantSetting. The column is still `NOT NULL` because
    # that callback always resolves a concrete value before the record is saved.
    add_column :card_grants, :allow_stripe_card, :boolean
    add_column :card_grants, :allow_reimbursement_report, :boolean

    safety_assured do
      # Existing grants were all card-based, so they can use a virtual card.
      execute <<~SQL
        UPDATE card_grants SET allow_stripe_card = true WHERE allow_stripe_card IS NULL
      SQL

      execute <<~SQL
        UPDATE card_grants
        SET allow_reimbursement_report = card_grant_settings.reimbursement_conversions_enabled
        FROM card_grant_settings
        WHERE card_grant_settings.event_id = card_grants.event_id
      SQL

      execute <<~SQL
        UPDATE card_grants SET allow_reimbursement_report = false WHERE allow_reimbursement_report IS NULL
      SQL

      change_column_null :card_grants, :allow_stripe_card, false
      change_column_null :card_grants, :allow_reimbursement_report, false
    end
  end

  def down
    remove_column :card_grants, :allow_stripe_card
    remove_column :card_grants, :allow_reimbursement_report
  end
end
