# frozen_string_literal: true

class WiseTransfersController < ApplicationController
  include SetEvent

  before_action :set_event, only: %i[new create]
  # before_action :set_wise_transfer, only: %i[approve reject send_wire edit update]

  def new
    @wise_transfer = @event.wise_transfers.build

    authorize @wise_transfer
  end

  def create
    @wise_transfer = @event.wise_transfers.build(wise_transfer_params.except(:file).merge(user: current_user))

    authorize @wise_transfer

    if @wise_transfer.amount_cents > 500_00
      return unless enforce_sudo_mode # rubocop:disable Style/SoleNestedConditional
    end

    if @wise_transfer.save
      if wise_transfer_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: wise_transfer_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @wise_transfer.local_hcb_code
        ).run!
      end
      redirect_to url_for(@wise_transfer.local_hcb_code), flash: { success: "Your wise transfer has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end
  end

  private

  def wise_transfer_params
    params.require(:wise_transfer).permit(
      [:memo,
       :amount,
       :payment_for,
       :recipient_name,
       :recipient_email,
       :account_number,
       :bic_code,
       :recipient_country,
       :currency,
       :address_line1,
       :address_line2,
       :address_city,
       :address_postal_code,
       :address_state,
       { file: [] }] + WiseTransfer.recipient_information_accessors
    )
  end

  def set_wise_transfer
    @wise_transfer = WiseTransfer.find(params[:id])
  end

end
