# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  # Emailed receipt requests link to a signed upload page that doesn't require
  # signing in. Marking no/lost receipt from that page shouldn't either.
  skip_before_action :signed_in_user, only: :mark_no_or_lost
  before_action :set_receiptable
  skip_after_action :verify_authorized # do not force pundit

  def mark_no_or_lost
    authorize @receiptable, policy_class: ReceiptablePolicy unless from_signed_link?

    if @receiptable.no_or_lost_receipt!
      flash[:success] = "Marked no/lost receipt on that transaction."
    else
      flash[:error] = "Failed to mark that transaction as no/lost receipt."
    end

    if from_signed_link?
      # Reuse the secret they arrived with, so they land back on the page they
      # started from and see the "Marked no/lost receipt" banner.
      redirect_to attach_receipt_hcb_code_path(id: @receiptable.hashid, s: params[:s])
    else
      redirect_to @receiptable
    end
  end

  private

  RECEIPTABLE_TYPE_MAP = [HcbCode, CanonicalTransaction, Transaction, StripeAuthorization,
                          EmburseTransaction, Reimbursement::Expense, Reimbursement::Expense::Mileage, Reimbursement::Expense::Fee,
                          Api::Models::CardCharge, Ledger::Item, Payment, Payroll::Invoice].index_by(&:to_s).freeze

  def set_receiptable
    return unless RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]

    @klass = RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]
    @receiptable = @klass.find(params[:receiptable_id])
  end

  # True when the request came from the signed link in a receipt request email,
  # which grants access without signing in (same secret the upload form uses).
  def from_signed_link?
    return @from_signed_link if defined?(@from_signed_link)

    @from_signed_link = @receiptable.is_a?(HcbCode) && params[:s].present? &&
                        HcbCode.find_signed(params[:s], purpose: :receipt_upload) == @receiptable
  end

end
