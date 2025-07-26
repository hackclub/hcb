# frozen_string_literal: true

class WiresController < ApplicationController
  include SetEvent

  before_action :set_event, only: %i[new create]
  before_action :set_wire, only: %i[approve reject send_wire edit update]

  def new
    @wire = @event.wires.build

    authorize @wire
  end

  def create
    @wire = @event.wires.build(wire_params.except(:file).merge(user: current_user))

    authorize @wire

    if @wire.save
      if wire_params[:file]
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: wire_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @wire.local_hcb_code
        ).run!
      end
      redirect_to url_for(@wire.local_hcb_code), flash: { success: "Your wire has been sent!" }
    else
      render "new", status: :unprocessable_entity
    end
  end

  def approve
    authorize @wire

    @wire.mark_approved!

    redirect_to wire_process_admin_path(@wire), flash: { success: "Thanks for sending that wire." }

  rescue => e
    redirect_to wire_process_admin_path(@wire), flash: { error: e.message }
  end

  def edit
    authorize @wire
    @event = @wire.event
  end

  def update
    authorize @wire
    @event = @wire.event
    if @wire.update(wire_params)
      redirect_to wire_process_admin_path(@wire), flash: { success: "Edited the wire." }
    else
      redirect_to wire_process_admin_path(@wire), flash: { error: @wire.errors.full_messages.to_sentence }
    end
  end


  def send_wire
    authorize @wire

    @wire.send_wire!

    redirect_to wire_process_admin_path(@wire), flash: { success: "Thanks for approving that wire." }

  rescue Faraday::Error => e
    redirect_to wire_process_admin_path(@wire), flash: { error: "Something went wrong: #{e.response_body["message"]}" }
  rescue => e
    redirect_to wire_process_admin_path(@wire), flash: { error: e.message }
  end

  def reject
    authorize @wire

    @wire.mark_rejected!

    @wire.local_hcb_code.comments.create(content: params[:comment], user: current_user, action: :rejected_transfer) if params[:comment]

    redirect_back_or_to wire_process_admin_path(@wire), flash: { success: "Wire has been canceled." }
  end

  private

  def wire_params
    params.require(:wire).permit(
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
       { file: [] }] + Wire.recipient_information_accessors
    )
  end

  def set_wire
    @wire = Wire.find(params[:id])
  end

end
