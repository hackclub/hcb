# frozen_string_literal: true

module Admin
  class LedgerAuditsController < AdminController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      @ledger_audits = Admin::LedgerAudit.all.order(created_at: :desc).includes(:admin_ledger_audit_tasks).where.not(admin_ledger_audit_tasks: { id: nil }).page(@page).per(@per)
    end

    def show
      @ledger_audit = Admin::LedgerAudit.find(params[:id])
      next_task = @ledger_audit.tasks.pending.first
      redirect_to admin_ledger_audits_task_path(next_task) and return if next_task.present?
    end

  end
end
