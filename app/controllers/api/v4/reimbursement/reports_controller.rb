# frozen_string_literal: true

module Api
  module V4
    module Reimbursement
      class ReportsController < ApplicationController
        before_action :set_report, only: [:show, :update, :destroy, :submit]

        include ApplicationHelper

        def index
          if params[:organization_id]
            @event = Event.find_by_public_id!(params[:organization_id])
            authorize @event, :show_in_v4?
            reports = @event.reimbursement_reports.order(created_at: :desc)
          else
            skip_authorization
            reports = current_user.reimbursement_reports.order(created_at: :desc)
          end

          @reports = paginate_cursor(reports.to_a, &:public_id)
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

          @report.mark_submitted!
          render :show, status: :ok
        end

        private

        def set_report
          @report = ::Reimbursement::Report.find_by_public_id!(params[:id])
        end

      end
    end
  end
end
