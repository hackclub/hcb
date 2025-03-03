# frozen_string_literal: true

class ExportsController < ApplicationController
  include SetEvent
  before_action :set_event, only: [:transactions, :reimbursements]
  skip_before_action :signed_in_user
  skip_after_action :verify_authorized, only: :collect_email

  def transactions
    authorize @event, :show?

    should_queue = @event.canonical_transactions.size > 300

    respond_to do |format|
      format.any(*export_options.keys) do
        file_extension = params[:format]

        if file_extension == "csv" && params[:start_date].present?
          # CSV exports **can** support date ranges
          set_date_range
        end

        if should_queue
          handle_large_export(file_extension)
        else
          send("stream_transactions_#{file_extension}")
        end
      end

      format.pdf do
        set_date_range # PDF monthly statements require a date range

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

  def reimbursements
    authorize @event, :reimbursements?

    respond_to do |format|
      format.csv do
        stream_reimbursements_csv
      end
    end
  end

  def collect_email
    if !params[:event_slug] || !params[:file_extension]
      redirect_to root_path
    end
    @event_slug = params[:event_slug]
    @file_extension = params[:file_extension]
  end

  private

  def set_date_range
    @start = (params[:start_date] || Date.today.prev_month).to_datetime.beginning_of_month
    if @start >= Date.today.beginning_of_month
      flash[:error] = "Can not create a financial statement for #{@start.strftime("%B %Y")}"
      redirect_back fallback_location: event_statements_path(@event) and return
    end
    @end = (params[:end_date] || @start).to_datetime.end_of_month
    if @end < @start
      flash[:error] = "End date cannot be before the start date."
      redirect_back fallback_location: event_statements_path(@event) and return
    end
  end

  def export_options
    {
      "csv"    => ExportJob::Csv,
      "json"   => ExportJob::Json,
      "ledger" => ExportJob::Ledger
    }
  end

  def handle_large_export(file_extension)
    additional_args = {}
    if file_extension == "csv" && @start
      additional_args.merge!(start_date: @start, end_date: @end)
    end

    if current_user
      export_job = export_options[file_extension]
      export_job.perform_later(event_id: @event.id, email: current_user.email, public_only: !organizer_signed_in?, **additional_args)
      flash[:success] = "This export is too big, so we'll send you an email when it's ready."
      redirect_back fallback_location: @event and return
    elsif params[:email]
      # this handles the second stage of large transparent exports
      export_job = export_options[file_extension]
      export_job.perform_later(event_id: @event.id, email: params[:email], public_only: true, **additional_args)
      flash[:success] = "We'll send you an email when your export is ready."
      redirect_to @event and return
    else
      # handles when large exports are requested by the non-signed-in users viewing transparent orgs
      # this redirects them to a form that collects their email and then goes to the above statement
      redirect_to collect_email_exports_path(file_extension:, event_slug: params[:event]) and return
    end
  end

  def stream_transactions_csv
    set_file_headers_csv
    set_streaming_headers

    response.status = 200

    self.response_body = transactions_csv
  end

  def stream_transactions_json
    set_file_headers_json
    set_streaming_headers

    response.status = 200

    self.response_body = transactions_json
  end

  def stream_transactions_ledger
    set_file_headers_ledger
    set_streaming_headers

    response.status = 200

    self.response_body = transactions_ledger
  end

  def stream_reimbursements_csv
    set_file_headers_csv
    set_streaming_headers

    response.status = 200

    self.response_body = reimbursements_csv
  end

  def set_file_headers_csv
    headers["Content-Type"] = "text/csv"
    headers["Content-disposition"] = "attachment; filename=#{@event.slug}_#{action_name}_#{Time.now.strftime("%Y%m%d%H%M")}.csv"
  end

  def set_file_headers_json
    headers["Content-Type"] = "application/json"
    headers["Content-disposition"] = "attachment; filename=#{@event.slug}_#{action_name}_#{Time.now.strftime("%Y%m%d%H%M")}.json"
  end

  def set_file_headers_ledger
    headers["Content-Type"] = "text/ledger"
    headers["Content-disposition"] = "attachment; filename=#{@event.slug}_#{action_name}_#{Time.now.strftime("%Y%m%d%H%M")}.ledger"
  end

  def transactions_csv
    ::ExportService::Csv.new(event_id: @event.id, public_only: !organizer_signed_in?, start_date: @start, end_date: @end).run
  end

  def transactions_json
    ::ExportService::Json.new(event_id: @event.id, public_only: !organizer_signed_in?).run
  end

  def transactions_ledger
    ::ExportService::Ledger.new(event_id: @event.id, public_only: !organizer_signed_in?).run
  end

  def reimbursements_csv
    ::ExportService::Reimbursement::Csv.new(event_id: @event.id, public_only: !organizer_signed_in?).run
  end

end
