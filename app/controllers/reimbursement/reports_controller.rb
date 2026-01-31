# frozen_string_literal: true

module Reimbursement
  class ReportsController < ApplicationController
    include SetEvent
    include Admin::TransferApprovable

    before_action :set_report_user_and_event, except: [:create, :quick_expense, :start, :finished]
    before_action :set_event, only: [:start, :finished]
    skip_before_action :signed_in_user, only: [:show, :start, :create, :finished]
    skip_after_action :verify_authorized, only: [:start, :finished]

    invisible_captcha only: [:create], honeypot: :subtitle

    # POST /reimbursement_reports
    def create
      @event = Event.find(report_params[:event_id])
      user = User.create_with(creation_method: :reimbursement_report).find_or_create_by!(email: report_params[:email])
      @report = @event.reimbursement_reports.build(report_params.except(:email, :receipt_id, :value).merge(user:, inviter: organizer_signed_in? ? current_user : nil, currency: user.payout_method&.currency || "USD"))

      authorize @report

      if @report.save
        if report_params[:receipt_id]
          @expense = @report.expenses.create!(value: report_params[:value], memo: report_params[:report_name])
          Receipt.find(report_params[:receipt_id]).update!(receiptable: @expense)
        end
        if current_user && user == current_user
          redirect_to @report
        elsif admin_signed_in? || organizer_signed_in?
          redirect_to event_reimbursements_path(@event), flash: { success: "Report successfully created." }
        else
          # User not signed in (creating via public page)
          redirect_to finished_reimbursement_reports_path(@event)
        end
      else
        redirect_back fallback_location: event_reimbursements_path(@event), flash: { error: @report.errors.full_messages.to_sentence }
      end
    end

    def quick_expense
      @event = Event.find(report_params[:event_id])
      @report = @event.reimbursement_reports.build({ user: current_user, inviter: current_user })

      authorize @report, :create?

      if @report.save
        @expense = @report.expenses.create!(amount_cents: 0)
        receipt = ::ReceiptService::Create.new(
          receiptable: @expense,
          uploader: current_user,
          attachments: params[:reimbursement_report][:file],
          upload_method: :quick_expense
        ).run!
        @expense.update(memo: receipt.first.suggested_memo, amount_cents: receipt.first.extracted_total_amount_cents) if receipt&.first&.suggested_memo
        redirect_to reimbursement_report_path(@report, edit: @expense.id)
      else
        redirect_to event_reimbursements_path(@event), flash: { error: @report.errors.full_messages.to_sentence }
      end

    end

    def show
      if !signed_in?
        skip_authorization
        url_queries = { return_to: reimbursement_report_path(@report) }
        url_queries[:email] = params[:email] if params[:email]
        return redirect_to auth_users_path(url_queries), flash: { info: "To continue, please sign in with the email which received the invite." }
      end
      authorize @report
      @commentable = @report
      @comments = @commentable.comments
      @use_user_nav = @event.nil? || current_user == @user && !@event.users.include?(@user) && !auditor_signed_in?
      @editing = params[:edit].to_i

    end

    def wise_transfer_quote
      authorize @report

      @with_fees_quote_amount = @report.wise_transfer_quote_amount
      @without_fees_quote_amount = @report.wise_transfer_quote_without_fees_amount
      @fees_amount = @with_fees_quote_amount - @without_fees_quote_amount

      render :wise_transfer_quote, layout: false
    end

    def wise_transfer_breakdown
      authorize @report

      if @report.payout_holding.present?
        @with_fees_quote_amount = Money.from_cents(@report.payout_holding.amount_cents)
        @fees_amount = Money.from_cents(@report.fees_charged_cents)
        @without_fees_quote_amount = @with_fees_quote_amount - @fees_amount
      else
        @with_fees_quote_amount = @report.wise_transfer_quote_amount
        @without_fees_quote_amount = @report.wise_transfer_quote_without_fees_amount
        @fees_amount = @with_fees_quote_amount - @without_fees_quote_amount
      end

      render :wise_transfer_breakdown, layout: false
    end

    def start
      unless @event.public_reimbursement_page_available?
        return not_found
      end
    end

    def update_currency
      authorize @report

      old_currency = @report.currency
      new_currency = @report.user.payout_method.currency

      ActiveRecord::Base.transaction do
        @report.update!(currency: new_currency)

        @report.expenses.each do |expense|
          fractional = Money.from_amount(expense.value, old_currency).cents
          full = Money.from_cents(fractional, new_currency).amount

          expense.update!(value: full)
        end
      end

      flash[:success] = "Report successfully updated to #{new_currency}."
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
    end

    def convert_to_wise_transfer
      authorize @report

      wise_transfer = @report.convert_to_wise_transfer!(as: current_user)

      flash[:success] = "Report successfully converted to Wise transfer."
      redirect_to wise_transfer_process_admin_path(wise_transfer)
    end

    def finished
    end

    def edit
      authorize @report
    end

    def update
      authorize @report

      if @report.update(update_reimbursement_report_params)
        flash[:success] = "Report successfully updated."
        if @report.event_id_previously_changed?
          PaperTrail.request(whodunnit: nil) do
            @report.expenses.update(aasm_state: :pending)
          end
        end
        redirect_to @report
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # The following routes handle state changes for the reports.

    def draft

      authorize @report

      begin
        @report.mark_draft!
        flash[:success] = "Report marked as a draft."
      rescue => e
        flash[:error] = e.message
      end

      redirect_to @report
    end

    def submit
      authorize @report

      begin
        @report.mark_submitted!

        comment_params = params[:comment]&.permit(:content, :admin_only, :action)

        unless comment_params.nil? || comment_params[:content].blank? && comment_params[:file].blank?
          @comment = @report.comments.build(comment_params.merge(user: current_user))
          unless @comment.save
            flash[:error] = @report.errors.full_messages.to_sentence
            redirect_to @report and return
          end
        end

        flash[:success] = {
          text: "Your report has been submitted for review. When it's approved, you'll be reimbursed via #{@report.user.payout_method.name}.",
          link: settings_payouts_path
        }
        if @report.user.can_update_payout_method?
          flash[:success][:link_text] = "If needed, you can still edit your payout settings."
        end
      rescue => e
        flash[:error] = e.message
      end

      redirect_to @report
    end

    def request_reimbursement

      authorize @report

      begin
        @report.mark_reimbursement_requested!
        flash[:success] = "Reimbursement requested; the HCB team will review the request promptly."
      rescue => e
        flash[:error] = e.message
      end

      redirect_to @report
    end

    def admin_approve
      authorize @report
      return unless enforce_sudo_mode

      # For Wise, the amount stored on the report is not in USD. By using the passed in :wise_total_including_fees parameter,
      # we're able to track admin transfer amounts based on the amounts used in the reimbursement processing flow.
      wise_amount_cents = (params[:wise_total_including_fees] * 100).to_i if @report.currency != "USD" && params[:wise_total_including_fees].present?
      ensure_admin_may_approve!(@report, amount_cents: wise_amount_cents || @report.amount_to_reimburse_cents)

      begin
        @report.with_lock do
          if params[:wise_total_without_fees] && params[:wise_total_including_fees]
            unless params[:wise_total_including_fees].to_f >= params[:wise_total_without_fees].to_f
              flash[:error] = "The total including fees must be greater than or equal to the total without fees."
              return redirect_to @report
            end

            unless params[:wise_total_including_fees].to_f <= 50_000.00
              flash[:error] = "The total including fees must be less than $50,000."
              return redirect_to @report
            end

            wise_total_including_fees_cents = params[:wise_total_including_fees].to_f * 100
            wise_total_without_fees_cents = params[:wise_total_without_fees].to_f * 100

            unless ::Shared::AmpleBalance.ample_balance?(wise_total_including_fees_cents.to_i, @report.event)
              flash[:error] = "This organization does not have sufficient funds to cover the transfer."
              return redirect_to @report
            end

            if @report.maximum_amount_cents.present? && wise_total_including_fees_cents.to_i > @report.maximum_amount_cents
              flash[:error] = "This amount is above the maximum amount set by the organizers."
              return redirect_to @report
            end

            conversion_rate = (wise_total_without_fees_cents / @report.amount_to_reimburse_cents).round(10)
            @report.update(conversion_rate:)
            approved_amount_usd_cents = @report.expenses.approved.sum { |expense| (expense.amount_cents * expense.conversion_rate).floor }
            fee_expense_value = (wise_total_including_fees_cents - approved_amount_usd_cents.to_f) / 100

            @report.expenses.create!(
              value: fee_expense_value,
              memo: "Wise transfer fee",
              type: Reimbursement::Expense::Fee,
              aasm_state: :approved,
              approved_by: current_user,
              approved_at: Time.now
            )
          end
          @report.mark_reimbursement_approved!
        end
        flash[:success] = "Reimbursement has been approved; the team & report creator will be notified."
      rescue => e
        flash[:error] = e.message
      end

      # Reimbursement::NightlyJob.perform_later

      redirect_to @report
    end

    def admin_send_wise_transfer
      authorize @report

      clearinghouse = Event.find_by(id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING)
      payout_holding = @report.payout_holding
      payout_holding.with_lock do
        unless payout_holding.settled?
          payout_holding.expense_payouts.pending.each do |expense_payout|
            Reimbursement::ExpensePayoutService::ProcessSingle.new(expense_payout_id: expense_payout.id).run
          end
          Reimbursement::PayoutHoldingService::ProcessSingle.new(payout_holding_id: payout_holding.id).run
          payout_holding.reload
          payout_holding.mark_settled!
        end
        @report.user.payout_method.update(wise_recipient_id: params[:wise_recipient_id])
        wise_transfer = clearinghouse.wise_transfers.create!(
          payment_for: "Reimbursement for #{@report.name}.",
          address_line1: @report.user.payout_method.address_line1,
          address_line2: @report.user.payout_method.address_line2,
          address_city: @report.user.payout_method.address_city,
          address_state: @report.user.payout_method.address_state,
          address_postal_code: @report.user.payout_method.address_postal_code,
          recipient_country: @report.user.payout_method.recipient_country,
          recipient_email: @report.user.email,
          recipient_name: @report.user.full_name,
          bank_name: @report.user.payout_method.bank_name,
          recipient_information: @report.user.payout_method.recipient_information,
          currency: @report.currency,
          user: User.system_user,
          usd_amount_cents: payout_holding.amount_cents,
          quoted_usd_amount_cents: payout_holding.amount_cents,
          amount_cents: @report.amount_to_reimburse_cents,
          wise_id: params[:wise_id],
          wise_recipient_id: params[:wise_recipient_id],
          sent_at: Time.now,
          recipient_phone_number: @report.user.phone_number,
        )
        wise_transfer.mark_approved!
        wise_transfer.mark_sent!
        payout_holding.wise_transfer = wise_transfer
        payout_holding.save!
        payout_holding.mark_sent!
      end

      redirect_to @report
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.message
      redirect_to @report
    end

    def approve_all_expenses
      authorize @report

      begin
        @report.expenses.each do |expense|
          expense.mark_approved!
        end
        flash[:success] = "All expenses have been approved; the report creator will be notified."
      rescue => e
        flash[:error] = e.message
      end

      # Reimbursement::NightlyJob.perform_later

      redirect_to @report
    end

    def reject

      authorize @report

      begin
        @report.mark_rejected!
        flash[:success] = "Rejected & closed the report; no further changes can be made."
      rescue => e
        flash[:error] = e.message
      end

      redirect_to @report
    end

    def reverse

      authorize @report

      if @report.payout_holding.nil?
        flash[:error] = "This report can't be reversed yet."
      else
        begin
          @report.payout_holding.reverse!
          flash[:success] = "Reversed the report."
        rescue => e
          flash[:error] = e.message
        end
      end

      redirect_to @report
    end

    # this is a custom method for creating a comment
    # that also makes the report as a draft.
    # - @sampoder

    def request_changes

      authorize @report

      comment_params = params.require(:comment).permit(:content, :admin_only, :action)

      if comment_params[:content].blank? && comment_params[:file].blank?
        flash[:success] = "We've sent this report back to #{@report.user.name} and marked it as a draft."
      else
        @comment = @report.comments.build(comment_params.merge(user: current_user))

        if @comment.save
          flash[:success] = "We've notified #{@report.user.name} of your requested changes."
        else
          flash[:error] = @report.errors.full_messages.to_sentence
          redirect_to @report and return
        end
      end

      begin
        @report.mark_draft!
      rescue => e
        flash[:error] = e.message
        redirect_to @report and return
      end

      redirect_to @report
    end

    def destroy

      authorize @report

      @report.destroy

      if organizer_signed_in? && @event
        redirect_to event_reimbursements_path(@event)
      else
        redirect_to my_reimbursements_path
      end
    end

    private

    def set_report_user_and_event
      @report = Reimbursement::Report.find(params[:report_id] || params[:id])
      @event = @report.event
      @user = @report.user
    rescue ActiveRecord::RecordNotFound
      return redirect_to root_path, flash: { error: "We couldn’t find that report; it may have been deleted." }
    end

    def report_params
      params.require(:reimbursement_report).permit(:report_name, :maximum_amount, :event_id, :email, :invite_message, :receipt_id, :value).compact_blank
    end

    def update_reimbursement_report_params
      reimbursement_report_params = params.require(:reimbursement_report).permit(:report_name, :event_id, :maximum_amount, :reviewer_id).compact
      reimbursement_report_params.delete(:maximum_amount) unless admin_signed_in? || @event&.users&.include?(current_user)
      reimbursement_report_params.delete(:maximum_amount) unless @report.draft? || @report.submitted?
      reimbursement_report_params
    end

  end
end
