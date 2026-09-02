# frozen_string_literal: true

class AddAllowColumnsToCardGrants < ActiveRecord::Migration[8.0]
  def change
    # Nullable: NULL means "inherit the event's CardGrantSetting default", mirroring
    # how merchant/category locks fall back to the event-level setting.
    add_column :card_grants, :allow_stripe_card, :boolean
    add_column :card_grants, :allow_reimbursement_report, :boolean
  end
end
