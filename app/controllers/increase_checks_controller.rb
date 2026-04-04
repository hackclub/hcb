# frozen_string_literal: true

class IncreaseChecksController < ApplicationController
  include SetEvent
  include Admin::TransferApprovable

  before_action :set_event, only: %i[new create]
  before_action :set_check, only: %i[approve reject]

  def new
    @check = @event.increase_checks.build

    authorize @check

    render layout: "transfer"
  end

  def create
    params[:increase_check][:amount] = Monetize.parse(params[:increase_check][:amount]).cents

    @check = @event.increase_checks.build(check_params.except(:file).merge(user: current_user))

    authorize @check

    if @check.amount > SudoModeHandler::THRESHOLD_CENTS
      return unless enforce_sudo_mode # rubocop:disable Style/SoleNestedConditional
    end

    if @check.save
      attach_receipt_to_hcb_code(check_params[:file], @check.local_hcb_code)
      redirect_to url_for(@check.local_hcb_code), flash: { success: "Your check has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end
  end

  def approve
    authorize @check
    return unless enforce_sudo_mode

    ensure_admin_may_approve!(@check, amount_cents: @check.amount)
    @check.send_check!

    redirect_to increase_check_process_admin_path(@check), flash: { success: "Check has been sent!" }

  rescue Faraday::Error => e
    redirect_to increase_check_process_admin_path(@check), flash: { error: "Something went wrong: #{e.response_body["message"]}" }
  rescue => e
    redirect_to increase_check_process_admin_path(@check), flash: { error: e }
  end

  def reject
    authorize @check

    add_rejection_comment(@check)

    @check.mark_rejected!

    redirect_back_or_to increase_check_process_admin_path(@check), flash: { success: "Check has been canceled." }
  end

  private

  def check_params
    params.require(:increase_check).permit(
      :memo,
      :amount,
      :payment_for,
      :recipient_name,
      :address_line1,
      :address_line2,
      :address_city,
      :address_state,
      :recipient_email,
      :send_email_notification,
      :address_zip,
      :payment_recipient_id,
      file: []
    )
  end

  def set_check
    @check = IncreaseCheck.find(params[:id])
  end

end
