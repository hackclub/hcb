# frozen_string_literal: true

# `allow_reimbursement_report` was added defaulting to false, but events that
# already permit reimbursement conversions were effectively offering
# reimbursements already, so they'd silently lose the option. New settings
# mirror `reimbursement_conversions_enabled` on create; existing ones need this.
class BackfillAllowReimbursementReportOnCardGrantSettings < ActiveRecord::Migration[8.1]
  def up
    CardGrantSetting.where(allow_reimbursement_report: false, reimbursement_conversions_enabled: true)
                    .update_all(allow_reimbursement_report: true)
  end

  def down
    # No-op: we can't tell backfilled rows apart from ones set by an organizer.
  end

end
