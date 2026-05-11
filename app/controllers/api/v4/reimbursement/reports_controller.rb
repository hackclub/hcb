# frozen_string_literal: true

module Api
  module V4
    module Reimbursement
      class ReportsController < ApplicationController
        before_action :set_report, only: [:show, :update, :destroy, :submit]

        def index
          if params[:organization_id]
            @event = Event.find_by_public_id!(params[:organization_id])
            authorize @event, :show_in_v4?
            reports = @event.reimbursement_reports.order(created_at: :desc)
          else
            skip_authorization
            reports = current_user.reimbursement_reports.order(created_at: :desc)
          end

          @total_count = reports.count
          @reports = paginate_reports(reports)
        end

        def show
          authorize @report
        end

        def create
          @event = Event.find_by_public_id!(params.dig(:reimbursement_report, :organization_id))

          report_params = params.require(:reimbursement_report).permit(
            :name,
            :invite_message,
            :maximum_amount_cents
          )

          @report = @event.reimbursement_reports.build(
            report_params.merge(
              user: current_user,
              inviter: current_user,
              currency: current_user.payout_method&.currency || "USD"
            )
          )

          authorize @report

          @report.save!

          render :show, status: :created
        end

        def update
          authorize @report

          update_params = params.require(:reimbursement_report).permit(
            :name,
            :maximum_amount_cents,
            :organization_id,
            :reviewer_id
          )

          if update_params[:organization_id]
            @report.event = Event.find_by_public_id!(update_params.delete(:organization_id))
            authorize @report, :change_event?
          end

          if update_params[:reviewer_id]
            @report.reviewer = User.find_by_public_id!(update_params.delete(:reviewer_id))
          end

          @report.update!(update_params)

          render :show, status: :ok
        end

        def destroy
          authorize @report
          @report.destroy!
          render json: { message: "Reimbursement report successfully deleted" }, status: :ok
        end

        def submit
          authorize @report, :submit?

          unless @report.may_mark_submitted?
            messages = submit_validation_messages(@report)
            return render json: { error: "invalid_operation", messages: }, status: :bad_request
          end

          @report.mark_submitted!
          render :show, status: :ok
        end

        private

        def submit_validation_messages(report)
          messages = []
          messages << "Report has no expenses" unless report.expenses.any?
          messages << "One or more expenses are missing receipts" if report.missing_receipts?
          messages << "One or more expenses have a zero amount" if report.expenses.any? { |e| e.amount.zero? }
          messages << "Report amount exceeds the maximum allowed" if report.exceeds_maximum_amount?
          messages << "Report amount is below the minimum required" if report.below_minimum_amount?
          messages << "Currency does not match your payout method" if report.mismatched_currency?
          messages << "Your payout method is not set up" unless report.user.payout_method.present?
          messages << "Your payout method is not supported" if report.user.payout_method.present? && report.user.payout_method.unsupported?
          messages << "Organization finances are currently frozen" if report.event&.financially_frozen?
          messages << "Report must belong to an organization" unless report.event.present?
          messages = ["Report cannot be submitted in its current state"] if messages.empty?
          messages
        end

        def set_report
          @report = ::Reimbursement::Report.find_by_public_id!(params[:id])
        end

        def paginate_reports(reports)
          limit = [params[:limit]&.to_i || 25, 100].min

          if params[:after]
            cursor = ::Reimbursement::Report.find_by_public_id(params[:after])
            return render json: { error: "bad_request", messages: ["Invalid cursor"] }, status: :bad_request unless cursor

            reports = reports.where("reimbursement_reports.created_at < ? OR (reimbursement_reports.created_at = ? AND reimbursement_reports.id < ?)", cursor.created_at, cursor.created_at, cursor.id)
          end

          page = reports.limit(limit + 1).to_a
          @has_more = page.length > limit
          page.first(limit)
        end

      end
    end
  end
end
