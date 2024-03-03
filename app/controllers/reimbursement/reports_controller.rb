# frozen_string_literal: true

module Reimbursement
  class ReportsController < ApplicationController
    include SetEvent
    before_action :set_event_user_and_event, except: [:create, :quick_expense, :start]
    before_action :set_event, only: [:start]
    skip_before_action :signed_in_user, only: [:show, :start, :create]
    skip_after_action :verify_authorized, only: [:show, :start]

    # POST /reimbursement_reports
    def create
      @event = Event.friendly.find(report_params[:event_id])
      user = User.find_or_create_by!(email: report_params[:email])
      @report = @event.reimbursement_reports.build(report_params.except(:email).merge(user:))

      authorize @report

      if @report.save!
        if current_user && (admin_signed_in? || organizer_signed_in?)
          redirect_to event_reimbursements_path(@event), flash: { success: "Report successfully created." }
        else
          flash[:success] = "We've sent an invitation to your email."
          redirect_back(fallback_location: reimbursement_start_reimbursement_report_path(@event))
        end
      else
        redirect_to event_reimbursements_path(@event), flash: { error: @report.errors.full_messages.to_sentence }
      end
    end

    def quick_expense
      @event = Event.friendly.find(report_params[:event_id])
      @report = @event.reimbursement_reports.build({
                                                     report_name: "#{Time.now.strftime("%-m/%d/%Y")} Expenses",
                                                     user: current_user
                                                   })

      authorize @report, :create?

      if @report.save!
        @expense = @report.expenses.build(report: @report, amount_cents: 0)
        @expense.save!
        ::ReceiptService::Create.new(
          receiptable: @expense,
          uploader: current_user,
          attachments: params[:reimbursement_report][:file],
          upload_method: :quick_expense
        ).run!
        redirect_to @report
      else
        redirect_to event_reimbursements_path(@event), flash: { error: @report.errors.full_messages.to_sentence }
      end

    end

    def start

    end

    def show
      if !signed_in?
        url_queries = { return_to: reimbursement_report_path(@report) }
        url_queries[:email] = params[:email] if params[:email]
        return redirect_to auth_users_path(url_queries), flash: { info: "To continue, please sign in with the email which received the invite." }
      end
      @commentable = @report
      @comments = @commentable.comments
      @comment = Comment.new
      @use_user_nav = true if current_user == @user && !@event.users.include?(@user)

      authorize @report
    end

    def edit
      authorize @report
    end

    def update
      authorize @report

      @report.assign_attributes(update_reimbursement_report_params)

      if @report.save
        flash[:success] = "Report successfully updated."
        redirect_to @report
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # The following routes handle state changes for the reports.

    def draft

      authorize @report

      if @report.mark_draft!
        flash[:success] = "Report marked as a draft, you can now make edits."
      else
        flash[:error] = @report.errors.full_messages.to_sentence
      end

      redirect_to @report
    end

    def submit
      authorize @report

      if @report.mark_submitted!
        flash[:success] = "Report submitted for review. To make further changes, mark it as a draft."
      else
        flash[:error] = @report.errors.full_messages.to_sentence
      end

      redirect_to @report
    end

    def request_reimbursement

      authorize @report

      if @report.mark_reimbursement_requested!
        flash[:success] = "Reimbursement requested; the HCB team will review the request promptly."
      else
        flash[:error] = @report.errors.full_messages.to_sentence
      end

      redirect_to @report
    end

    def admin_approve

      authorize @report

      if @report.mark_reimbursement_approved!
        flash[:success] = "Reimbursement has been approved; the team & report creator will be notified."
      else
        flash[:error] = @report.errors.full_messages.to_sentence
      end

      redirect_to @report
    end

    def reject

      authorize @report

      if @report.mark_rejected!
        flash[:success] = "Rejected & closed the report; no further changes can be made."
      else
        flash[:error] = @report.errors.full_messages.to_sentence
      end

      redirect_to @report
    end

    # this is a custom method for creating a comment
    # that also makes the report as a draft.
    # - @sampoder

    def request_changes

      authorize @report

      @report.mark_draft!

      the_comment = params.require(:comment).permit(:content, :file, :admin_only, :action)

      if the_comment[:content].blank?
        flash[:success] = "We've sent this report back to #{@report.user.name} and marked it as a draft."
      else
        @comment = @report.comments.build(the_comment)
        @comment.user = current_user

        if @comment.save
          flash[:success] = "We've notified #{@report.user.name} of your requested changes."
        else
          flash[:error] = @report.errors.full_messages.to_sentence
        end
      end

      redirect_to @report
    end

    private

    def set_event_user_and_event
      @report = Reimbursement::Report.find(params[:report_id] || params[:id])
      @event = @report.event
      @user = @report.user
    end

    def report_params
      report_params = params.require(:reimbursement_report).permit(:report_name, :maximum_amount, :event_id, :user_email, :other_email, :invite_message)
      report_params[:maximum_amount] = report_params[:maximum_amount].presence
      report_params[:email] = report_params[:user_email] == "other" || report_params[:user_email].nil? ? report_params[:other_email] : report_params[:user_email]
      report_params.except(:user_email, :other_email)
    end

    def update_reimbursement_report_params
      reimbursement_report_params = params.require(:reimbursement_report).permit(:report_name, :event_id, :maximum_amount)
      reimbursement_report_params[:maximum_amount] = reimbursement_report_params[:maximum_amount].presence
      reimbursement_report_params.delete(:maximum_amount) unless @current_user.admin? || @current_user != @report.user
      reimbursement_report_params
    end

  end
end
