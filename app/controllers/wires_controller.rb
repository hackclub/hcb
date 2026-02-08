# frozen_string_literal: true

class WiresController < ApplicationController
  include SetEvent
  include Admin::TransferApprovable

  before_action :set_event, only: %i[new create]
  before_action :set_wire, only: %i[approve reject send_wire edit update]

  def new
    @wire = @event.wires.build

    authorize @wire

    render layout: "transfer"
  end

  def create
    @wire = @event.wires.build(wire_params.except(:file).merge(user: current_user))

    authorize @wire

    if @wire.amount_cents > SudoModeHandler::THRESHOLD_CENTS
      return unless enforce_sudo_mode # rubocop:disable Style/SoleNestedConditional
    end

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
    return unless enforce_sudo_mode

    ensure_admin_may_approve!(@wire, amount_cents: @wire.usd_amount_cents)
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

    ensure_admin_may_approve!(@wire, amount_cents: @wire.usd_amount_cents)
    @wire.send_wire!

    if params[:charge_fee] == "1"
      disbursement = DisbursementService::Create.new(
        name: "Low-value wire transfer fee",
        destination_event_id: EventMappingEngine::EventIds::HACK_CLUB_BANK,
        source_event_id: @wire.event.id,
        amount: 25,
        requested_by_id: current_user.id,
        fronted: @wire.event.plan.front_disbursements_enabled?
      ).run

      disbursement.local_hcb_code.comments.create(content: "Associated with #{hcb_code_url(@wire.local_hcb_code)}", user: current_user)
    end

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
       :payment_recipient_id,
       :send_email_notification,
       :idempotency_key,
       { file: [] }] + Wire.recipient_information_accessors
    )
  end

  def set_wire
    @wire = Wire.find(params[:id])
  end

end
