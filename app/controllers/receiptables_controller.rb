# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  before_action :set_receiptable
  skip_after_action :verify_authorized # do not force pundit

  def mark_no_or_lost
    if @receiptable.no_or_lost_receipt!
      flash[:success] = "Marked no/lost receipt on that transaction."
      redirect_to @receiptable
    else
      flash[:error] = "Failed to mark that transaction as no/lost receipt."
      redirect_back(fallback_location: @receiptable)
    end
  end

  private

  RECEIPTABLE_TYPE_MAP = [HcbCode, CanonicalTransaction, Transaction, StripeAuthorization,
                          EmburseTransaction, Reimbursement::Expense, Reimbursement::Expense::Mileage,
                          Api::Models::CardCharge].index_by(&:to_s).freeze

  def set_receiptable
    return unless RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]

    @klass = RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]
    @receiptable = @klass.find(params[:receiptable_id])
  end

end
