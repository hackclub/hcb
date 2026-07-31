# frozen_string_literal: true

class PaymentsController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:new, :create]
  before_action :set_payment, only: [:show, :cancel]

  def show
    authorize @payment
    @event = @payment.event
    @payout_method = @payment.attempts.first&.payout_method || @payment.legal_entity&.default_payout_method
  end

  def new
    authorize @event, policy_class: PaymentPolicy
    @payment = Payment.new
    @payee = @event.payees.not_archived.find_by_hashid(params[:payee_id]) if params[:payee_id].present?
    @recent_payments = @payee.payments.order(created_at: :desc).limit(5) if @payee
    render layout: "transfer"
  end

  def create
    authorize @event, policy_class: PaymentPolicy

    @payee = @event.payees.not_archived.find_by_hashid!(payment_params[:payee_id])
    @legal_entity = @payee.legal_entity
    @payment = Payment.new(payment_params.except(:payee_id, :file).merge(creator: current_user, payee: @payee, currency: "USD"))

    if payment_params[:file].blank?
      flash.now[:error] = "Please attach a receipt or invoice for this payment."
      return render :new, layout: "transfer", status: :unprocessable_content
    end

    if @payment.amount_cents > @event.balance_available_v2_cents
      flash.now[:error] = "Your organization doesn't have enough money to send this payment! Your balance is #{helpers.render_money(@event.balance_available_v2_cents)}."
      return render :new, layout: "transfer", status: :unprocessable_content
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
    render :new, layout: "transfer", status: :unprocessable_content
  end

  def cancel
    authorize @payment

    @payment.mark_canceled!

    flash[:success] = "Payment canceled"
    redirect_back_or_to payment_path(@payment)
  end

  private

  def build_payout_method
    type = params.dig(:user, :payout_method_type).presence
    return unless LegalEntity::PayoutMethod.details_class_for(type)

    details_attrs = LegalEntity::PayoutMethod.details_params_from(params, type)

    # ACH methods pre-fills existing payout details with masked values (ex ••••1234)
    return if @legal_entity.default_payout_method && details_attrs.values.any? { |value| value.to_s.include?("•") }

    LegalEntity::PayoutMethodService::Update.new(
      legal_entity: @legal_entity,
      details_type: type,
      details_attrs:,
      make_default: true
    ).run!
  end

  def payment_params
    params.require(:payment).permit(:amount, :purpose, :payee_id, file: [])
  end

  def set_payment
    @payment = Payment.find(params[:id])
  end

end
