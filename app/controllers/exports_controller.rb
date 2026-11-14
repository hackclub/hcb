# frozen_string_literal: true

class ExportsController < ApplicationController
  include SetEvent
  include SetLedgerFilters
  before_action :set_event, only: [:transactions, :reimbursements, :ledger]
  # Before the filters resolve: resolving them is expensive (merchants alone
  # load every transaction in the organization), so settle whether the
  # requester may see the ledger at all first.
  before_action :authorize_ledger, only: [:ledger]
  before_action :set_ledger_filters, only: [:ledger]
  skip_before_action :signed_in_user
  skip_after_action :verify_authorized, only: :collect_email

  def transactions
    authorize @event, :show?

    # One block per format, so the format comes from the block respond_to
    # chose: params[:format] is nil without a path extension, and a wildcard
    # Accept (curl's default) matches the first block listed.
    respond_to do |format|
      format.csv do
        # CSV exports **can** support date ranges
        if params[:start_date].present?
          set_date_range
          return if performed?
        end

        @export = Export::Event::Transactions::Csv.new(
          requested_by: current_user,
          event_id: @event.id,
          start_date: @start,
          end_date: @end,
          public_only: !organizer_signed_in?
        )

        deliver_export(@export, file_extension: :csv, filters: statement_range_params)
      end

      format.json do
        @export = Export::Event::Transactions::Json.new(
          requested_by: current_user,
          event_id: @event.id,
          public_only: !organizer_signed_in?
        )

        deliver_export(@export, file_extension: :json)
      end

      format.ledger do
        @export = Export::Event::Transactions::Ledger.new(
          requested_by: current_user,
          event_id: @event.id,
          public_only: !organizer_signed_in?
        )

        deliver_export(@export, file_extension: :ledger)
      end

      format.pdf do
        set_date_range # PDF monthly statements require a date range
        return if performed?

        all = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
        TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: all, event: @event).run!

        all.reverse.reduce(0) do |running_total, transaction|
          transaction.running_balance = running_total + transaction.amount
        end
        @transactions = all.select { |t| t.date >= @start && t.date <= @end }
        @start_balance = if @transactions.length > 0
                           @transactions.last.running_balance - @transactions.last.amount
                         elsif all.size.zero?
                           0
                         else
                           # Get the running balance of the first transaction immediately before the start date
                           # or if there's no transaction before the start date, $0.
                           all.find { |t| t.date < @start }&.running_balance || 0
                         end
        @end_balance = @transactions.first&.running_balance || @start_balance

        @withdrawn = 0
        @deposited = 0
        @transactions.each do |ct|
          if ct.amount > 0
            @deposited += ct.amount
          else
            @withdrawn -= ct.amount
          end
        end

        render pdf: "#{helpers.possessive(@event.name)} #{@start.strftime("%B %Y")} Statement", page_height: "11in", page_width: "8.5in"
      end
    end
  end

  # Exports the new ledger. Unlike #transactions, which always exported the
  # whole organization no matter what the page was showing, this exports exactly
  # what the ledger page is showing: the query carrying the user's filters is
  # what generates the file.
  def ledger
    respond_to do |format|
      # One block per format, so the format comes from the block respond_to
      # chose. Neither params[:format] (nil without a path extension) nor
      # request.format (nil on a wildcard Accept, which is what curl sends)
      # reliably says which that was.
      ::Ledger::Query::Export::FORMATS.each_key do |as|
        format.public_send(as) { export_ledger(as:) }
      end
    end
  end

  def reimbursements
    authorize @event, :reimbursements?

    respond_to do |format|
      format.csv do
        @export = Export::Event::Reimbursements::Csv.create(
          requested_by: current_user,
          event_id: @event.id
        )
        headers["Content-Type"] = @export.mime_type
        headers["Content-disposition"] = "attachment; filename=#{@export.filename}"
        response.status = 200
        self.response_body = @export.content
      end
    end
  end

  def collect_email
    if !params[:event_slug] || !params[:file_extension]
      redirect_to root_path and return
    end

    @event_slug = params[:event_slug]
    @file_extension = params[:file_extension]
    # Only signed-out readers land here (a signed-in user always has an address
    # to mail the export to). They can't use the filter menu, but they can
    # search, and the export they asked for is the search's results, so the
    # search has to make the round trip. The form is a GET, which replaces the
    # URL's query string with its own fields, so the filters ride as fields.
    if params[:source] == "ledger"
      @export_path = ledger_exports_path(event: @event_slug, format: @file_extension)
      @filters = ledger_filter_params
    else
      @export_path = transactions_exports_path(event: @event_slug, format: @file_extension)
      @filters = statement_range_params
    end
  end

  private

  # The date range a legacy CSV export can be narrowed to, as params, for the
  # same round trip through the email form that the ledger filters make.
  def statement_range_params
    params.permit(:start_date, :end_date).to_h.compact_blank.symbolize_keys
  end

  def authorize_ledger
    authorize @event, :show?

    # An organization with no ledger has nothing to export; without this the
    # query would scope to a nil ledger and serve an empty file as the whole
    # ledger.
    not_found if @event.ledger.nil?
  end

  def export_ledger(as:)
    @export = ledger_query.export(
      as:,
      ledgers: @ledgers,
      event_id: @event.id,
      requested_by: current_user,
      public_only: !organizer_signed_in?,
      filtered: ledger_filtered?
    )

    deliver_export(@export, file_extension: as, filters: ledger_filter_params)
  end

  # Serves an export inline, or — when it's too big to generate in a request —
  # queues it up to be emailed, collecting an address first if we don't have one.
  # `filters` are the params that narrowed the export; they travel with the
  # request for an address so the export that's eventually emailed is the one
  # that was asked for.
  def deliver_export(export, file_extension:, filters: {})
    if export.async?
      # A signed-in user's export is always emailed to them. Only a
      # signed-out requester (which `authorize` in the caller limits to public
      # orgs) may supply an address via `params[:email]`. Honoring the
      # param for signed-in users would let a forged cross-site GET mail a
      # private ledger to an attacker-chosen address.
      export.requested_by ||= User.find_or_create_by(email: params[:email]) if params[:email].present?

      if export.requested_by.nil?
        redirect_to collect_email_exports_path(file_extension:, event_slug: params[:event], source: action_name, **filters) and return
      end

      export.save!

      ExportJob.perform_later(export_id: export.id)

      flash[:success] = signed_in? ? "This export is too big, so we'll send you an email when it's ready." : "Your export will arrive in a few moments."

      redirect_back fallback_location: @event and return
    end

    export.save!
    headers["Content-Type"] = export.mime_type
    headers["Content-disposition"] = "attachment; filename=#{export.filename}"
    response.status = 200
    self.response_body = export.content
  end

  # Sets `@start` and `@end`, or renders a 400 when the requested range is
  # invalid. Callers must `return if performed?`.
  def set_date_range
    start_date = params[:start_date].present? ? parse_date_param(params[:start_date]) : Date.today.prev_month
    end_date = params[:end_date].present? ? parse_date_param(params[:end_date]) : start_date

    if start_date.nil? || end_date.nil?
      return render plain: "Invalid date.", status: :bad_request
    end

    @start = start_date.beginning_of_month
    if @start >= Date.today.beginning_of_month
      return render plain: "Can not create a financial statement for #{@start.strftime("%B %Y")}.", status: :bad_request
    end

    @end = end_date.end_of_month
    if @end < @start
      render plain: "End date cannot be before the start date.", status: :bad_request
    end
  end

end
