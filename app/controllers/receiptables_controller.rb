# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  # Emailed receipt requests link to a signed upload page that doesn't require
  # signing in. Submitting a lost receipt statement shouldn't either.
  skip_before_action :signed_in_user, only: [:lost_receipt, :mark_no_or_lost]
  before_action :set_receiptable
  before_action :authorize_receiptable

  def lost_receipt
    @statement = LostReceipt::Statement.new(
      date: @receiptable.try(:date) || @receiptable.try(:datetime)&.to_date,
      merchant: @receiptable.try(:memo),
      signer_name: current_user&.full_name,
      submitter: current_user
    )
    @statement.items << LostReceipt::Item.new(quantity: 1)
  end

  def mark_no_or_lost
    receiptable = @receiptable.is_a?(Ledger::Item) ? (@receiptable.hcb_code || raise(ActiveRecord::RecordNotFound)) : @receiptable
    @statement = LostReceipt::Statement.new(statement_params)
    @statement.submitter = current_user

    if @statement.submit(receiptable:)
      flash[:success] = "Lost receipt statement added."
      # Signed link visitors can't view the transaction itself.
      fallback = from_signed_link? ? attach_receipt_hcb_code_path(@receiptable, s: params[:s]) : @receiptable
      redirect_to url_from(params[:return_to]) || fallback
    else
      render :lost_receipt, status: :unprocessable_entity
    end
  rescue ActiveRecord::NestedAttributes::TooManyRecords
    render plain: "A lost receipt statement can contain at most 50 items.", status: :unprocessable_entity
  end

  private

  def statement_params
    return {} unless params.key?(:lost_receipt_statement)

    params.expect(lost_receipt_statement: [:date, :merchant, :purpose, :signer_name, :confirmed,
                                           { items_attributes: [[:description, :quantity, :unit_amount, :unit_amount_cents]] }])
  end

  def authorize_receiptable
    # Always run the policy, even for the signed link, so that Pundit's
    # `verify_authorized` can stay on: an action that forgets to authorize now
    # fails loudly rather than silently allowing the request through.
    begin
      authorize @receiptable, :mark_no_or_lost?, policy_class: ReceiptablePolicy
    rescue Pundit::NotAuthorizedError
      raise unless from_signed_link?
    end
  end

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
  # Possession of the link permits submission, but does not verify the typed
  # signer's identity; the PDF explicitly distinguishes this from signing in.
  def from_signed_link?
    return @from_signed_link if defined?(@from_signed_link)

    @from_signed_link = @receiptable.is_a?(HcbCode) && params[:s].present? &&
                        HcbCode.find_signed(params[:s], purpose: :receipt_upload) == @receiptable
  end

end
