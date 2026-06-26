# frozen_string_literal: true

require "csv"

class TransactSoNsController < ApplicationController
  skip_before_action :signed_in_user

  def index
    authorize TransactSON

    @needs_action = TransactSON.needs_action
    @transact_so_ns = TransactSON.order(:date).includes(:bank_account).page params[:page]
  end

  def show
    begin
      # DEPRECATED
      @transact_son = TransactSON.with_deleted.find(params[:id])
      @event = @transact_son.event

      authorize @transact_son

      render :show_deprecated
    rescue ActiveRecord::RecordNotFound => e
      @transact_son = CanonicalTransaction.find(params[:id])

      authorize @transact_son

      @event = @transact_son.event
      @hcb_code = @transact_son.local_hcb_code
    end
  end

  def edit
    @transact_son = TransactSON.find(params[:id])
    authorize @transact_son
    @event = @transact_son.event

    # so the fee relationship fields render
    if @transact_son.fee_relationship.nil?
      @transact_son.fee_relationship = FeeRelationship.new

      # If a new transaction is positive, we would probably charge a fee
      if @transact_son.is_event_related && @transact_son.amount > 0 &&
         !@transact_son.potential_github? &&
         !@transact_son.potential_disbursement?
        @transact_son.fee_relationship.fee_applies = true
      end

      if @transact_son.potential_fee_payment?
        @transact_son.fee_relationship.is_fee_payment = true
      end
    end
  end

  def update
    @transact_son = TransactSON.find(params[:id])
    authorize @transact_son

    currently_categorized = @transact_son.categorized?
    fee_relationship = @transact_son.fee_relationship
    current_fee_reimbursement = @transact_son.fee_reimbursement

    @transact_son.assign_attributes(transaction_params)

    # NOTE: @transaction is the record, .transaction is a keyword here
    @transact_son.transaction do
      if !@transact_son.is_event_related
        @transact_son.fee_relationship = nil
        should_delete_fee_relationship = true if fee_relationship&.persisted?
      end

      if current_fee_reimbursement.nil? && @transact_son.fee_reimbursement.present?
        @transact_son.fee_relationship = FeeRelationship.new(
          event_id: @transact_son.fee_reimbursement.event.id,
          fee_applies: true,
          fee_amount: @transact_son.fee_reimbursement.calculate_fee_amount
        )
      end

      if @transact_son.save
        # need to destroy the fee relationship here because we have a foreign
        # key that'll be erased on the @transaction.save
        fee_relationship.destroy! if should_delete_fee_relationship

        redirect_to @transact_son
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def transaction_params
    params.require(:transact_son).permit(
      :is_event_related,
      :emburse_transfer_id,
      :invoice_payout_id,
      :display_name,
      :fee_reimbursement_id,
      :check_id,
      :disbursement_id,
      :ach_transfer_id,
      :donation_payout_id,
      # TODO: I (@zrl) think users might be able to mess with the fee
      # relationship ID on the clientside.
      fee_relationship_attributes: [
        :id,
        :event_id,
        :fee_applies,
        :is_fee_payment
      ]
    )
  end

end
