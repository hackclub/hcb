# frozen_string_literal: true

class PaymentsController < ApplicationController
  include SetEvent

  before_action :set_event, except: [:show]

  def show
    @payment = Payment.find(params[:id])
    authorize @payment
    @event = @payment.event
  end

  def new
    authorize @event, policy_class: PaymentPolicy
    @payment = Payment.new
    @payee = @event.payees.find_by(id: params[:payee_id]) if params[:payee_id].present?
    render layout: "transfer"
  end

  def create
    authorize @event, policy_class: PaymentPolicy

    if payment_params[:file].blank?
      @payee = @event.payees.find_by(id: payment_params[:payee_id])
      @payment = Payment.new(payment_params.except(:payee_id, :file))
      flash.now[:error] = "Please attach a receipt or invoice for this payment."
      return render :new, layout: "transfer", status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @payee = @event.payees.find(payment_params[:payee_id])
      @legal_entity = @payee.legal_entity

      # On the manual path the payee has a managed legal entity (created on the
      # recipient step); the payout method the organizer entered is saved here.
      build_payout_method if @legal_entity&.managed?

      @payment = Payment.new(payment_params.except(:payee_id, :file).merge(creator: current_user, payee: @payee, currency: "USD"))
      @payment.save!

      if payment_params[:file].present?
        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: payment_params[:file],
          upload_method: :transfer_create_page,
          receiptable: @payment
        ).run!
      end
    end

    redirect_to event_payments_path(event_id: @event.slug), notice: "Payment submitted for review."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:error] = e.message
    render :new, layout: "transfer", status: :unprocessable_entity
  end

  private

  def build_payout_method
    type = params.dig(:user, :payout_method_type).presence
    return unless LegalEntity::PayoutMethod.details_class_for(type)

    LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      legal_entity: @legal_entity,
      details_type: type,
      details_attrs: LegalEntity::PayoutMethod.details_params_from(params, type),
      make_default: true
    ).run!
  end

  def payment_params
    params.require(:payment).permit(:amount, :purpose, :payee_id, file: [])
  end

end
