# frozen_string_literal: true

class ReceiptablesController < ApplicationController
  # Emailed receipt requests link to a signed upload page that doesn't require
  # signing in. Submitting a lost receipt statement shouldn't either.
  skip_before_action :signed_in_user, only: [:lost_receipt, :mark_no_or_lost]
  before_action :set_receiptable
  before_action :authorize_receiptable
  before_action :require_markable_receiptable

  def lost_receipt
    # First ask whether they've really looked for the receipt.
    return render_page(:lost_receipt_tips) unless params[:continue]

    @statement = LostReceipt::Statement.new(
      receiptable: @transaction,
      date: @transaction.try(:date) || @transaction.try(:datetime)&.to_date,
      merchant: @transaction.try(:memo),
      submitter: current_user
    )
    @statement.items << LostReceipt::Item.new(quantity: 1)
    render_page(:lost_receipt)
  end

  def mark_no_or_lost
    @statement = LostReceipt::Statement.new(statement_params)
    @statement.receiptable = @transaction
    @statement.submitter = current_user

    if @statement.submit
      flash[:success] = "Lost receipt statement submitted. The PDF will appear here in a moment."
      redirect_to safe_url(params[:return_to]) || fallback_location
    else
      render_page :lost_receipt, status: :unprocessable_entity
    end
  rescue ActiveRecord::NestedAttributes::TooManyRecords
    render plain: "A lost receipt statement can have at most 50 items.", status: :unprocessable_entity
  end

  private

  def render_page(template, **options)
    # The link can sit inside a frame or popover, so the referer is the only reliable way back.
    @return_to = safe_url(params[:return_to]) || (safe_url(request.referrer) unless request.post?)
    @back_url = @return_to || url_for(fallback_location)
    # Where the upload box is, for someone who found their receipt.
    @upload_url = url_for(fallback_location)
    @hide_transfer_notes = true
    render template, layout: "transfer", **options
  end

  # url_from only checks the host, which a javascript: URL can fake, and this ends up in an href.
  def safe_url(url)
    url_from(url) if url.to_s.start_with?("/", "http://", "https://")
  end

  # Payments, reimbursement expenses and the like can't be marked no/lost, and aren't always in USD.
  def require_markable_receiptable
    raise ActiveRecord::RecordNotFound unless @receiptable.try(:has_attribute?, :marked_no_or_lost_receipt_at)

    # The page may be opened for the ledger item; the statement describes its HCB code.
    @transaction = hcb_code || @receiptable
  end

  # Signed link visitors can't view the transaction itself.
  def fallback_location
    from_signed_link? ? attach_receipt_hcb_code_path(hcb_code, s: params[:s]) : @transaction
  end

  def statement_params
    return {} unless params.key?(:lost_receipt_statement)

    params.expect(lost_receipt_statement: [:date, :merchant, :purpose, :signer_name, :confirmed, :acknowledgement,
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

  # The transaction's HCB code, whether the receiptable is the code itself or
  # its ledger item. Nil for every other receiptable.
  def hcb_code
    @hcb_code ||= @receiptable.try(:receipt_hcb_code)
  end

  # True when the request came from the signed link in a receipt request email,
  # which grants access without signing in (same secret the upload form uses).
  # The link doesn't prove who typed the name, so the PDF says when it was used.
  def from_signed_link?
    return @from_signed_link if defined?(@from_signed_link)

    @from_signed_link = hcb_code.present? && params[:s].present? &&
                        HcbCode.find_signed(params[:s], purpose: :receipt_upload) == hcb_code
  end

end
