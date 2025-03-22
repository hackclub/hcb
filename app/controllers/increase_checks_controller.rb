# frozen_string_literal: true

class IncreaseChecksController < ApplicationController
  include SetEvent

  before_action :set_event, only: %i[new create]
  before_action :set_check, only: %i[approve reject]

  def new
    @check = @event.increase_checks.build

    authorize @check
  end

  def create
    params[:increase_check][:amount] = Monetize.parse(params[:increase_check][:amount]).cents

    @check = @event.increase_checks.build(check_params.except(:file).merge(user: current_user))

    authorize @check

    if @check.save
      if check_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: check_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @check.local_hcb_code
        ).run!
      end
      redirect_to url_for(@check.local_hcb_code), flash: { success: "Your check has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end
  end

  def approve
    authorize @check

    @check.send_check!

    redirect_to increase_check_process_admin_path(@check), flash: { success: "Check has been sent!" }

  rescue Faraday::Error => e
    redirect_to increase_check_process_admin_path(@check), flash: { error: "Something went wrong: #{e.response_body["message"]}" }
  rescue => e
    redirect_to increase_check_process_admin_path(@check), flash: { error: e }
  end

  def reject
    authorize @check

    @check.local_hcb_code.comments.create(content: params[:comment], user: current_user, action: :rejected_transfer) if params[:comment]

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
      file: []
    )
  end

  def set_check
    @check = IncreaseCheck.find(params[:id])
  end

end
