# frozen_string_literal: true

class RemoveHcbCodeIdFromSuggestedPairings < ActiveRecord::Migration[8.1]
  def change
    # Suggested pairings point at the transaction's ledger item now
    # (https://github.com/hackclub/hcb/issues/15698). The column is already
    # ignored by SuggestedPairing and nothing writes it. Drop it; Postgres
    # drops its two indexes with it.
    safety_assured do
      remove_column :suggested_pairings, :hcb_code_id, :bigint
    end
  end

end
