class AllowNullInAffiliationEvent < ActiveRecord::Migration[8.0]
  def change
    # Only change column if it exists (may have been removed by an earlier migration)
    #
    # In production, this migration ran before
    # 20260203031519_remove_event_id_from_affiliations due to PR merge order.
    #
    # This migration:    https://github.com/hackclub/hcb/pull/12884
    # Earlier migration: https://github.com/hackclub/hcb/pull/12864
    if column_exists?(:event_affiliations, :event_id)
      change_column_null :event_affiliations, :event_id, true
    end
  end
end
