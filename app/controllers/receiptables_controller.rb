# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  # Emailed receipt requests link to a signed upload page that doesn't require
  # signing in. Marking no/lost receipt from that page shouldn't either.
  skip_before_action :signed_in_user, only: :mark_no_or_lost
  before_action :set_receiptable

  def mark_no_or_lost
    # Always run the policy, even for the signed link, so that Pundit's
    # `verify_authorized` can stay on: an action that forgets to authorize now
    # fails loudly rather than silently allowing the request through.
    begin
      authorize @receiptable, policy_class: ReceiptablePolicy
    rescue Pundit::NotAuthorizedError
      raise unless from_signed_link?
    end

    if @receiptable.no_or_lost_receipt!
      flash[:success] = "Marked no/lost receipt on that transaction."
      # Signed link visitors can't view the transaction itself, so send them
      # back where they came from, reusing the secret they arrived with.
      redirect_to from_signed_link? ? attach_receipt_hcb_code_path(@receiptable, s: params[:s]) : @receiptable
    else
      flash[:error] = "Failed to mark that transaction as no/lost receipt."
      redirect_back(fallback_location: @receiptable)
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
