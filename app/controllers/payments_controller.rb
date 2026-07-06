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

    manual = params[:manual] == "true"

    ActiveRecord::Base.transaction do
      if manual
        @legal_entity = LegalEntity.create!(managing_event: @event, entity_type: :business, name: params[:payee_name])
        @payee = Payee.create!(display_name: params[:payee_name], email: params[:payee_email], event: @event, legal_entity: @legal_entity)
        build_payout_method
      else
        @payee = @event.payees.find(payment_params[:payee_id])
      end

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
    type, details = payout_method_params.values_at(:type, :details)
    return if type.blank?

    LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      legal_entity: @legal_entity,
      details_type: type,
      details_attrs: details,
      make_default: true
    ).run!
  end

  def payment_params
    params.require(:payment).permit(:amount, :purpose, :payee_id, file: [])
  end

  def payout_method_params
    type_name = params.dig(:user, :payout_method_type).presence
    details_class = LegalEntity::PayoutMethod.details_class_for(type_name)
    return { type: nil, details: {} } unless details_class

    key = :"payout_method_#{details_class.name.demodulize.underscore}"
    details = params.require(:user).permit(key => details_class.permitted_attributes)[key] || {}
    { type: type_name, details: }
  end

end
