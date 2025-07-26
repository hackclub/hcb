# frozen_string_literal: true

module Admin
  module LedgerAudits
    class TasksController < AdminController
      def index
        @tasks = Admin::LedgerAudit::Task.flagged.page(params[:page]).per(25)
      end

      def show
        @task = Admin::LedgerAudit::Task.find(params[:id])
        @ledger_audit = @task.admin_ledger_audit
      end

      def reviewed
        @task = Admin::LedgerAudit::Task.find(params[:task_id])
        @pending = @task.status == "pending"
        @task.update(status: "reviewed", reviewer: current_user)
        redirect_to @task.admin_ledger_audit and return if @pending

        redirect_to admin_ledger_audits_tasks_path
      end

      def flagged
        @task = Admin::LedgerAudit::Task.find(params[:task_id])
        @pending = @task.status == "pending"
        @task.update(status: "flagged", reviewer: current_user)
        redirect_to @task.admin_ledger_audit and return if @pending

        redirect_to admin_ledger_audits_tasks_path
      end

      def create
        hcb_code = HcbCode.find(params[:hcb_code])
        if Admin::LedgerAudit::Task.where(hcb_code:, status: "flagged").none?
          @task = Admin::LedgerAudit::Task.create(hcb_code:, status: "flagged", reviewer: current_user)
          if @task.save
            flash[:success] = "Transaction flagged, thanks."
          else
            flash[:error] = "Failed to flag this HCB code."
          end
        else
          flash[:success] = "This transaction has already flagged, thanks."
        end

        redirect_to hcb_code
      end

    end
  end
end
