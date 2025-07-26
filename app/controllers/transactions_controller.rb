# frozen_string_literal: true

require "csv"

class TransactionsController < ApplicationController
  skip_before_action :signed_in_user

  def index
    authorize Transaction

    @needs_action = Transaction.needs_action
    @transactions = Transaction.order(:date).includes(:bank_account).page params[:page]
  end

  def show
    begin
      # DEPRECATED
      @transaction = Transaction.with_deleted.find(params[:id])
      @event = @transaction.event

      @commentable = @transaction
      @comments = @commentable.comments
      @comment = Comment.new

      authorize @transaction

      render :show_deprecated
    rescue ActiveRecord::RecordNotFound => e
      @transaction = CanonicalTransaction.find(params[:id])

      authorize @transaction

      @event = @transaction.event
      @hcb_code = @transaction.local_hcb_code
    end
  end

  def edit
    @transaction = Transaction.find(params[:id])
    authorize @transaction
    @event = @transaction.event

    # so the fee relationship fields render
    if @transaction.fee_relationship.nil?
      @transaction.fee_relationship = FeeRelationship.new

      # If a new transaction is positive, we would probably charge a fee
      if @transaction.is_event_related && @transaction.amount > 0 &&
         !@transaction.potential_github? &&
         !@transaction.potential_disbursement?
        @transaction.fee_relationship.fee_applies = true
      end

      if @transaction.potential_fee_payment?
        @transaction.fee_relationship.is_fee_payment = true
      end
    end
  end

  def update
    @transaction = Transaction.find(params[:id])
    authorize @transaction

    currently_categorized = @transaction.categorized?
    fee_relationship = @transaction.fee_relationship
    current_fee_reimbursement = @transaction.fee_reimbursement

    @transaction.assign_attributes(transaction_params)

    # NOTE: @transaction is the record, .transaction is a keyword here
    @transaction.transaction do
      if !@transaction.is_event_related
        @transaction.fee_relationship = nil
        should_delete_fee_relationship = true if fee_relationship&.persisted?
      end

      if current_fee_reimbursement.nil? && @transaction.fee_reimbursement.present?
        @transaction.fee_relationship = FeeRelationship.new(
          event_id: @transaction.fee_reimbursement.event.id,
          fee_applies: true,
          fee_amount: @transaction.fee_reimbursement.calculate_fee_amount
        )
      end

      if @transaction.save
        # need to destroy the fee relationship here because we have a foreign
        # key that'll be erased on the @transaction.save
        fee_relationship.destroy! if should_delete_fee_relationship

        redirect_to @transaction
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(
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
