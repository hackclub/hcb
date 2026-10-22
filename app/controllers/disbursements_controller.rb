# frozen_string_literal: true

class DisbursementsController < ApplicationController
  include TurboStreamFlash
  include ComboboxSearchable

  before_action :set_disbursement, only: [:show, :edit, :update, :transfer_confirmation_letter]

  def show
    authorize @disbursement

    # Comments
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @disbursement.outgoing_hcb_code)
  end

  def transfer_confirmation_letter
    authorize @disbursement

    respond_to do |format|
      unless @disbursement.fulfilled?
        redirect_to @disbursement and return
      end

      format.html do
        redirect_to @disbursement
      end

      format.pdf do
        render pdf: "HCB Transfer ##{@disbursement.id} Confirmation Letter (#{@disbursement.source_event.name} to #{@disbursement.destination_event.name} on #{@disbursement.created_at})", page_height: "11in", page_width: "8.5in"
      end

      # not being used at the moment
      format.png do
        send_data ::DocumentPreviewService.new(type: :disbursement_confirmation, disbursement: @disbursement, event: @event).run, filename: "transfer_confirmation_letter.png"
      end

    end
  end

  def new
    @destination_event = Event.friendly.find(params[:event_id]) if params[:event_id]
    @source_event = Event.friendly.find(params[:source_event_id]) if params[:source_event_id]
    @event = @source_event # this is to render the navigation bar for the correct event.
    @disbursement = Disbursement.new(
      destination_event: @destination_event,
      source_event: @source_event,
      amount: params[:amount],
      name: params[:message]
    )

    authorize @disbursement
    prefill_repayment
    render layout: "transfer"
  end

  def event_search
    authorize Disbursement.new
    q = params[:q].to_s.presence
    # Indicates whether we're searching for source or destination organizations
    sending = params[:sending] == "true"

    user_event_ids = current_user.organizer_positions.reorder(sort_index: :asc).pluck(:event_id)

    own_events = current_user.disbursement_source_events
    own_event_ids = own_events.ids.to_set

    # As a destination, also suggest transparent organizations the user belongs
    # to in any role (e.g. as a member), since anyone can transfer into those.
    # Unlisted ones would otherwise only be reachable by typing the exact slug.
    own_destination_events = own_events.or(current_user.readable_events.accepting_public_transfers)

    base = if admin_signed_in?
             Event.select(:name, :id, :demo_mode, :slug).reorder(Event::CUSTOM_SORT).includes(:plan)
           elsif sending
             own_events
           elsif q.blank?
             # Until the user starts searching for a destination, only suggest
             # their own organizations.
             own_destination_events
           else
             # Once they search, also offer organizations in HCB's public
             # directory, plus an unlisted transparent organization when its
             # exact slug is typed. Anyone can already view these, so listing
             # them doesn't reveal anything. Private organizations stay hidden.
             public_events = Event.accepting_public_transfers
             own_destination_events
               .or(public_events.where(is_indexable: true))
               .or(public_events.where(slug: q.downcase))
               .select(:name, :id, :demo_mode, :slug).includes(:plan)
           end

    # Apply fuzzy search if query present
    if q.present?
      sql = "name ILIKE :name OR slug ILIKE :slug"
      sql += " OR CAST(id AS TEXT) ILIKE :id" if admin_signed_in?
      base = base.where(sql, name: "%#{q}%", slug: "%#{q}%", id: "%#{q}%")
    end

    # Rank exact matches first, then the user's own events (in their preferred
    # order), then prefix and substring matches, keeping the relation's
    # existing order as a tiebreaker.
    order_clauses = []
    if q.present?
      order_clauses << Arel.sql(
        ActiveRecord::Base.sanitize_sql_array(
          ["CASE WHEN LOWER(name) = LOWER(:exact) OR LOWER(slug) = LOWER(:exact) THEN 0 ELSE 1 END", { exact: q }]
        )
      )
    end
    if user_event_ids.any?
      ids = user_event_ids.map(&:to_i).join(", ")
      order_clauses << Arel.sql("array_position(ARRAY[#{ids}]::bigint[], events.id) NULLS LAST")
    end
    if q.present?
      order_clauses << Arel.sql(
        ActiveRecord::Base.sanitize_sql_array(
          ["CASE WHEN name ILIKE :prefix OR slug ILIKE :prefix THEN 0 ELSE 1 END", { prefix: "#{q}%" }]
        )
      )
    end
    order_clauses.concat(base.order_values)
    order_clauses << Arel.sql("events.id ASC")

    events = combobox_page(base.reorder(*order_clauses)).to_a

    options = events.map do |e|
      disabled_message = nil
      disabled_message = "Insufficient balance" if sending && !admin_signed_in? && e.balance_available <= 0
      disabled_message = "HCB transfers disabled" if sending && !policy(e).create_transfer?
      # Balances are expensive to compute, so only show the user's own.
      balance = helpers.render_money_short(e.balance_available) if admin_signed_in? || own_event_ids.include?(e.id)

      option = {
        value: e.public_id,
        label: helpers.combobox_display(e),
        sublabel: disabled_message || balance,
        disabled: disabled_message.present?
      }
      # Lets the form hide the repayment option for recipients whose
      # transactions the user can't see.
      option[:repayable] = policy(Disbursement.new(destination_event: e)).repay? unless sending
      option
    end

    render json: options
  end

  REPAYABLE_TRANSACTIONS_PER_PAGE = 25

  # Expenses of the destination organization that the source can repay, as
  # rows for the repayment picker.
  def repayable_transactions
    authorize Disbursement.new, :event_search?
    @destination_event = Event.find_by_public_id(params[:destination_event_id])

    @items = if @destination_event && policy(Disbursement.new(destination_event: @destination_event)).repay?
               repayable_transactions_query
                 .execute(ledgers: [@destination_event.ledger])
                 .where(id: Repayment.unrepaid_ledger_items(@destination_event).select(:id))
             else
               Ledger::Item.none
             end
    @items = @items.page(params[:page]).per(REPAYABLE_TRANSACTIONS_PER_PAGE)

    render layout: false
  end

  def create
    @source_event = Event.find_by_public_id(disbursement_params[:source_event_id])
    @destination_event = Event.find_by_public_id(disbursement_params[:event_id]) || Event.friendly.find(disbursement_params[:event_id])
    @event = @source_event # this is to render the navigation bar for the correct event.
    @disbursement = Disbursement.new(
      destination_event: @destination_event,
      source_event: @source_event,
      amount: Monetize.parse(disbursement_params[:amount])&.cents,
      name: disbursement_params[:name]
    )

    authorize @disbursement

    if admin_signed_in? && disbursement_params["scheduled_on(1i)"].present?
      scheduled_on = Date.new(disbursement_params["scheduled_on(1i)"].to_i,
                              disbursement_params["scheduled_on(2i)"].to_i,
                              disbursement_params["scheduled_on(3i)"].to_i)
    end

    transfer_type = disbursement_params[:transfer_type].presence

    if transfer_type == "repayment"
      authorize @disbursement, :repay?
      repaid_ledger_item = Ledger::Item.find_by_hashid(disbursement_params[:repaid_ledger_item_id])
    end

    source_transaction_category_slug = disbursement_params[:source_transaction_category_slug].presence
    destination_transaction_category_slug = disbursement_params[:destination_transaction_category_slug].presence
    # Plain transfers are categorized for the user; anything they chose, or an
    # admin overrode, is manual.
    category_assignment_strategy = transfer_type == "transfer" && source_transaction_category_slug.nil? && destination_transaction_category_slug.nil? ? "automatic" : "manual"

    disbursement = DisbursementService::Create.new(
      name: disbursement_params[:name],
      destination_event_id: @destination_event.id,
      source_event_id: @source_event.id,
      amount: disbursement_params[:amount],
      scheduled_on:,
      requested_by_id: current_user.id,
      should_charge_fee: disbursement_params[:should_charge_fee] == "1",
      fronted: Disbursement.frontable?(source_event: @source_event, destination_event: @destination_event, requested_by: current_user),
      source_transaction_category_slug:,
      destination_transaction_category_slug:,
      category_assignment_strategy:,
      transfer_type:,
      repaid_ledger_item_id: repaid_ledger_item&.id
    ).run

    if disbursement_params[:file]
      ::ReceiptService::Create.new(
        uploader: current_user,
        attachments: disbursement_params[:file],
        upload_method: :transfer_create_page,
        receiptable: disbursement.local_hcb_code
      ).run!
    end

    flash[:success] = "Transfer successfully requested."

    if admin_signed_in?
      redirect_to disbursements_admin_index_path
    else
      redirect_to event_transfers_path(@source_event)
    end

  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash.now[:error] = e.message
    render :new, layout: "transfer", status: :unprocessable_content
  rescue ActiveRecord::RecordNotFound => e
    skip_authorization
    flash[:error] = "Organization not found: #{e.id}"
    redirect_to new_disbursement_path(source_event_id: @source_event)
  end

  def edit
    authorize @disbursement
  end

  def update
    authorize @disbursement
  end

  def cancel
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement
    @disbursement.mark_rejected!
    redirect_to @disbursement.local_hcb_code
  end

  def set_transaction_categories
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    category_params =
      params
      .require(:disbursement)
      .permit(:source_transaction_category_slug, :destination_transaction_category_slug )

    updates = {}

    [:source_transaction_category, :destination_transaction_category].each do |field|
      param = "#{field}_slug"
      next unless category_params.key?(param)

      slug = category_params[param]

      updates[field] =
        if slug.blank?
          nil
        else
          TransactionCategory.find_or_initialize_by(slug:)
        end
    end

    @disbursement.update!(updates)

    message = "Transaction category was successfully updated."

    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = message
        update_flash_via_turbo_stream(use_admin_layout: true)
      end
      format.html do
        redirect_to(
          disbursement_path(@disbursement),
          flash: { success: message }
        )
      end
    end
  end

  def mark_fulfilled
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    if @disbursement.mark_in_transit!
      flash[:success] = "Disbursement marked as fulfilled"
      if Disbursement.pending.any?
        redirect_to disbursements_admin_index_path(pending: 1)
      else
        redirect_to disbursements_admin_index_path
      end
    end
  end

  def reject
    @disbursement = Disbursement.find(params[:disbursement_id])
    authorize @disbursement

    begin
      @disbursement.mark_rejected!(current_user)
      flash[:success] = "Disbursement rejected"
    rescue => e
      flash[:error] = e.message
    end

    redirect_to disbursement_path(@disbursement)
  end

  private

  # "Repay this" on a transaction links here with the transaction picked. Links
  # can go stale (the transaction gets repaid, or the user loses access), so an
  # item that can't be repaid is dropped rather than raised on.
  def prefill_repayment
    return unless @destination_event && params[:repaid_ledger_item_id].present?
    return unless policy(Disbursement.new(destination_event: @destination_event)).repay?

    @repaid_ledger_item = Repayment.unrepaid_ledger_items(@destination_event).find_by_hashid(params[:repaid_ledger_item_id])
    return unless @repaid_ledger_item

    @disbursement.transfer_type = :repayment
    @disbursement.amount = -@repaid_ledger_item.amount_cents
    @disbursement.name = "Repaying #{@repaid_ledger_item.memo}".truncate(60) if @disbursement.name.blank?
  end

  def repayable_transactions_query
    query = []

    if params[:q].present?
      search = [{ memo: { "$search": params[:q] } }]
      # Memos repeat ("AMZN Mktp"), so a number also matches the exact amount.
      amount = params[:q].strip.delete("$,")
      search << { amount_cents: -(BigDecimal(amount) * 100).to_i } if amount.match?(/\A\d+(\.\d{1,2})?\z/)
      query << { "$or": search }
    end

    start_date = date_param(:start)
    end_date = date_param(:end)
    query << { datetime: { "$gte": start_date } } if start_date
    query << { datetime: { "$lt": end_date.next_day } } if end_date
    query << { category: { "$eq": params[:category] } } if params[:category].present?

    Ledger::Query.new({ "$and": query })
  end

  def date_param(name)
    Date.iso8601(params[name]) if params[name].present?
  rescue Date::Error, TypeError
    nil
  end

  # Only allow a trusted parameter "white list" through.
  def disbursement_params
    attributes = [
      :source_event_id,
      :event_id,
      :amount,
      :name,
      :scheduled_on,
      :transfer_type,
      :repaid_ledger_item_id,
      { file: [] }
    ]

    if admin_signed_in?
      attributes.push(
        :should_charge_fee,
        :source_transaction_category_slug,
        :destination_transaction_category_slug
      )
    end

    params.require(:disbursement).permit(attributes)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_disbursement
    @disbursement = Disbursement.find(params[:id] || params[:disbursement_id])
    @event = @disbursement.event
  end

end
