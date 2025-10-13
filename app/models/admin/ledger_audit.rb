# frozen_string_literal: true

# == Schema Information
#
# Table name: admin_ledger_audits
#
#  id         :bigint           not null, primary key
#  start      :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

module Admin
  class LedgerAudit < ApplicationRecord
    self.table_name = "admin_ledger_audits"
    has_many :admin_ledger_audit_tasks, class_name: "Admin::LedgerAudit::Task", foreign_key: "admin_ledger_audit_id", inverse_of: "admin_ledger_audit"
    alias_method :tasks, :admin_ledger_audit_tasks
    has_many :hcb_codes, through: :admin_ledger_audit_tasks
    scope :pending, -> { joins(:admin_ledger_audit_tasks).where("admin_ledger_audit_tasks.status" => "pending").distinct }


  end
end
