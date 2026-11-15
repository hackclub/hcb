# frozen_string_literal: true

# == Schema Information
#
# Table name: admin_ledger_audit_tasks
#
#  id                    :bigint           not null, primary key
#  status                :string           default("pending")
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  admin_ledger_audit_id :bigint
#  hcb_code_id           :bigint
#  ledger_item_id        :bigint
#  reviewer_id           :bigint
#
# Indexes
#
#  index_admin_ledger_audit_tasks_on_admin_ledger_audit_id  (admin_ledger_audit_id)
#  index_admin_ledger_audit_tasks_on_hcb_code_id            (hcb_code_id)
#  index_admin_ledger_audit_tasks_on_ledger_item_id         (ledger_item_id)
#  index_admin_ledger_audit_tasks_on_reviewer_id            (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_ledger_audit_id => admin_ledger_audits.id)
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#  fk_rails_...  (reviewer_id => users.id)
#

module Admin
  class LedgerAudit
    class Task < ApplicationRecord
      belongs_to :admin_ledger_audit, class_name: "Admin::LedgerAudit", optional: true
      belongs_to :hcb_code, optional: true
      belongs_to :ledger_item, class_name: "Ledger::Item", optional: true, inverse_of: :admin_ledger_audit_tasks
      belongs_to :reviewer, class_name: "User", optional: true
      scope :pending, -> { where("status = ?", "pending") }
      scope :flagged, -> { where("status = ?", "flagged") }

      before_create :fill_in_counterparty

      private

      # TODO: fully migrate to ledger item
      def fill_in_counterparty
        if hcb_code.nil? && ledger_item.present?
          self.hcb_code = ledger_item.hcb_code
        elsif ledger_item.nil? && hcb_code.present?
          self.ledger_item = hcb_code.ledger_item
        end
      end

    end

  end
end
