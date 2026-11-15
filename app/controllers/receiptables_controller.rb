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
      submitter: current_user
    )
    @statement.items << LostReceipt::Item.new(quantity: 1)
    render_form
  end

  def mark_no_or_lost
    receiptable = @receiptable.is_a?(Ledger::Item) ? (@receiptable.hcb_code || raise(ActiveRecord::RecordNotFound)) : @receiptable
    @statement = LostReceipt::Statement.new(statement_params)
    @statement.submitter = current_user

    if @statement.submit(receiptable:)
      flash[:success] = "Lost receipt statement added."
      redirect_to url_from(params[:return_to]) || fallback_location
    else
      render_form status: :unprocessable_entity
    end
  rescue ActiveRecord::NestedAttributes::TooManyRecords
    render plain: "A lost receipt statement can have at most 50 items.", status: :unprocessable_entity
  end

  private

  def render_form(**options)
    # The link can sit inside a frame or popover, so the referer is the only reliable way back.
    @return_to = url_from(params[:return_to]) || (url_from(request.referrer) if request.get?)
    @back_url = @return_to || url_for(fallback_location)
    @can_transfer = false # hides the transfer layout's steps and review note
    render :lost_receipt, layout: "transfer", **options
  end

  # Signed link visitors can't view the transaction itself.
  def fallback_location
    from_signed_link? ? attach_receipt_hcb_code_path(@receiptable, s: params[:s]) : @receiptable
  end

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
  # The link doesn't prove who typed the name, so the PDF says when it was used.
  def from_signed_link?
    return @from_signed_link if defined?(@from_signed_link)

    @from_signed_link = @receiptable.is_a?(HcbCode) && params[:s].present? &&
                        HcbCode.find_signed(params[:s], purpose: :receipt_upload) == @receiptable
  end

end
