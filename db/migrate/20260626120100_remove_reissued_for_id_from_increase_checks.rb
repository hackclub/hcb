# frozen_string_literal: true

class RemoveReissuedForIdFromIncreaseChecks < ActiveRecord::Migration[8.0]
  def change
    # reissued_for_id backed check reissuing, which was removed (#13653). The
    # column is already ignored by IncreaseCheck. Drop it; Postgres drops the
    # dependent index and self-referential foreign key with it.
    safety_assured do
      remove_column :increase_checks, :reissued_for_id, :bigint
    end
  end

end
