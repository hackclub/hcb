# frozen_string_literal: true

class PaymentsController < ApplicationController
  include SetEvent

  before_action :set_event, except: [:show]

  def show
    @payment = Payment.find(params[:id])
    authorize @payment
    @event = @payment.event
    @payout_method = @payment.attempts.first&.payout_method || @payment.legal_entity&.default_payout_method
  end

  def new
    authorize @event, policy_class: PaymentPolicy
    @payment = Payment.new
    @payee = @event.payees.find_by_public_id(params[:payee_id]) if params[:payee_id].present?
    render layout: "transfer"
  end

  def create
    authorize @event, policy_class: PaymentPolicy

    @payee = @event.payees.find_by_public_id!(payment_params[:payee_id])
    @legal_entity = @payee.legal_entity
    @payment = Payment.new(payment_params.except(:payee_id, :file).merge(creator: current_user, payee: @payee, currency: "USD"))

    if payment_params[:file].blank?
      flash.now[:error] = "Please attach a receipt or invoice for this payment."
      return render :new, layout: "transfer", status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      # On the manual path the payee has a managed legal entity (created on the
      # recipient step); the payout method the organizer entered is saved here.
      build_payout_method if @legal_entity&.managed?

      @payment.save!

      ::ReceiptService::Create.new(
        uploader: current_user,
        attachments: payment_params[:file],
        upload_method: :transfer_create_page,
        receiptable: @payment
      ).run!
    end

    flash[:success] = "Payment submitted for review"
    redirect_to payment_path(@payment)
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:error] = e.message
    render :new, layout: "transfer", status: :unprocessable_entity
  end

  private

  def build_payout_method
    type = params.dig(:user, :payout_method_type).presence
    return unless LegalEntity::PayoutMethod.details_class_for(type)

    details_attrs = LegalEntity::PayoutMethod.details_params_from(params, type)

    return if @legal_entity.default_payout_method && details_attrs.values.any? { |value| value.to_s.include?("•") }

    LegalEntity::PayoutMethodService::Update.new(
      user: current_user,
      legal_entity: @legal_entity,
      details_type: type,
      details_attrs:,
      make_default: true
    ).run!
  end

  def payment_params
    params.require(:payment).permit(:amount, :purpose, :payee_id, file: [])
  end

end
