# frozen_string_literal: true

class EventsController < ApplicationController
  TRANSACTIONS_PER_PAGE = 75
  DONATIONS_PER_PAGE = 25

  include SetEvent

  include Rails::Pagination
  before_action :set_event, except: [:index]
  before_action :set_transaction_filters, only: [:transactions, :ledger]
  before_action except: [:show, :index] do
    render_back_to_tour @organizer_position, :welcome, event_path(@event)
  end
  skip_before_action :signed_in_user
  before_action :set_event_follow, only: [:show, :transactions, :announcement_overview]

  before_action :redirect_to_onboarding, unless: -> { @event&.is_public? }
  before_action :set_timeframe, only: [:merchants_chart, :categories_chart, :tags_chart, :users_chart]

  # GET /events
  def index
    authorize Event
    respond_to do |format|
      format.json do
        events =
          @current_user
          .events
          .with_attached_logo
          .preload(:config)
          .reorder("organizer_positions.sort_index ASC", "events.id ASC")
          .strict_loading
          .map { |event| serialize_event(event, member: true) }

        if auditor_signed_in?
          events.concat(
            Event
              .excluding(@current_user.events)
              .with_attached_logo
              .preload(:config)
              .strict_loading
              .map { |event| serialize_event(event, member: false) }
          )
        end

        render json: events
      end
      format.html { redirect_to root_path }
    end
  end

  # GET /events/1
  def show
    begin
      authorize @event
    rescue Pundit::NotAuthorizedError
      return redirect_to root_path, flash: { error: "We couldn’t find that organization!" }
    end
  end

  def transaction_heatmap
    authorize @event
    heatmap_engine_response = BreakdownEngine::Heatmap.new(@event).run

    @heatmap = heatmap_engine_response[:heatmap]
    @maximum_positive_change = heatmap_engine_response[:maximum_positive_change]
    @maximum_negative_change = heatmap_engine_response[:maximum_negative_change]
    @past_year_transactions_count = heatmap_engine_response[:transactions_count]

    render partial: "events/home/heatmap", locals: { heatmap: @heatmap, event: @event }
  end

  def merchants_chart
    authorize @event

    @merchants = BreakdownEngine::Merchants.new(@event, start_date: @timeframe&.ago).run

    render partial: "events/home/merchants_chart", locals: { timeframe: params[:timeframe] }
  end

  def categories_chart
    authorize @event

    @categories = BreakdownEngine::Categories.new(@event, start_date: @timeframe&.ago).run

    render partial: "events/home/categories_chart", locals: { timeframe: params[:timeframe] }
  end

  def balance_transactions
    authorize @event

    pending_transactions = _show_pending_transactions
    canonical_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
    all_transactions = [*pending_transactions, *canonical_transactions]

    @recent_transactions = all_transactions.first(6)

    render partial: "events/home/balance_transactions", locals: { heatmap: @heatmap, event: @event }
  end

  def money_movement
    authorize @event

    pending_transactions = _show_pending_transactions
    canonical_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
    all_transactions = [*pending_transactions, *canonical_transactions]

    @money_in = all_transactions.reject { |t| t.amount_cents <= 0 }.first(3)
    @money_out = all_transactions.reject { |t| t.amount_cents >= 0 }.first(3)

    render partial: "events/home/money_movement", locals: { heatmap: @heatmap, event: @event }
  end

  def team_stats
    authorize @event

    @organizers = @event.organizer_positions.joins(:user).order(Arel.sql("CONCAT(preferred_name, full_name) ASC"))

    render partial: "events/home/team_stats", locals: { merchants: @merchants, categories: @categories, event: @event }
  end

  def recent_activity
    authorize @event

    @activities = PublicActivity::Activity.for_event(@event).order(created_at: :desc).first(7)

    render partial: "events/home/recent_activity", locals: { merchants: @merchants, categories: @categories, event: @event }
  end

  def tags_chart
    authorize @event

    @tags = BreakdownEngine::Tags.new(@event, start_date: @timeframe&.ago).run

    render partial: "events/home/tags_chart", locals: { tags: @tags, timeframe: params[:timeframe], event: @event }
  end

  def users_chart
    authorize @event

    @users = BreakdownEngine::Users.new(@event, start_date: @timeframe&.ago).run

    render partial: "events/home/users_chart", locals: { users: @users, timeframe: params[:timeframe], event: @event }
  end

  def transactions
    render_tour @organizer_position, :welcome

    maybe_pending_invite = OrganizerPositionInvite.pending.find_by(user: current_user, event: @event)

    if maybe_pending_invite.present?
      skip_authorization
      return redirect_to maybe_pending_invite
    end

    begin
      authorize @event
    rescue Pundit::NotAuthorizedError
      return redirect_to root_path, flash: { error: "We couldn’t find that organization!" }
    end

    if flash[:popover]
      @popover = flash[:popover]
      flash.delete(:popover)
    end
  end

  def ledger
    begin
      authorize @event
    rescue Pundit::NotAuthorizedError
      return redirect_to root_path, flash: { error: "We couldn’t find that organization!" }
    end

    set_cacheable

    @order_by = auditor_signed_in? && params[:order_by] || "date"

    @pending_transactions = _show_pending_transactions
    @all_transactions = TransactionGroupingEngine::Transaction::All.new(
      event_id: @event.id,
      search: params[:q],
      tag_id: @tag&.id,
      revenue: @direction == "revenue",
      expenses: @direction == "expenses",
      minimum_amount: @minimum_amount,
      maximum_amount: @maximum_amount,
      user: @user,
      start_date: @start_date,
      end_date: @end_date,
      missing_receipts: @missing_receipts,
      category: @category,
      merchant: @merchant,
      order_by: @order_by.to_sym,
      subledger: params[:subledger]
    ).run

    if (@minimum_amount || @maximum_amount) && !organizer_signed_in?
      @all_transactions.reject!(&:likely_account_verification_related?)
    end

    type_results = self.class.filter_transaction_type(@type, settled_transactions: @all_transactions, pending_transactions: @pending_transactions)
    @all_transactions = type_results[:settled_transactions]
    @pending_transactions = type_results[:pending_transactions]

    page = (params[:page] || 1).to_i
    per_page = (params[:per] || TRANSACTIONS_PER_PAGE).to_i

    @transactions = Kaminari.paginate_array(@all_transactions).page(page).per(per_page)
    TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: @transactions, event: @event).run!

    if show_running_balance?
      offset = page * per_page

      initial_subtotal = if @all_transactions.count > offset
                           TransactionGroupingEngine::Transaction::RunningBalanceAssociationPreloader.new(transactions: @all_transactions, event: @event).run!
                           # sum up transactions on pages after this one to get the initial subtotal
                           @all_transactions.slice(offset...).map(&:amount).sum
                         else
                           # this is the last page, so start from 0
                           0
                         end

      @transactions.reverse.reduce(initial_subtotal) do |running_total, transaction|
        transaction.running_balance = running_total + transaction.amount
      end
    end

    render layout: !turbo_frame_request? && auditor_signed_in?
  end

  def balance_by_date
    authorize @event

    max = [365, (Date.today - @event.created_at.to_date).to_i + 5].min

    balance_by_date = Rails.cache.fetch("balance_by_date_#{@event.id}", expires_in: 5.minutes) do
      ::TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).running_balance_by_date
    end

    balance_by_date[0.days.ago.to_date] = @event.balance_v2_cents

    begin
      if (balance_by_date[max.days.ago.to_date] || balance_by_date[balance_by_date.keys.first]) > balance_by_date[0.days.ago.to_date]
        balance_trend = "down"
      else
        balance_trend = "up"
      end
    rescue
      balance_trend = "up"
    end

    render json: {
      balanceByDate: balance_by_date,
      balanceTrend: balance_trend
    }
  end

  def team
    authorize @event

    case params[:filter]
    when "members"
      @filter = "member"
    when "managers"
      @filter = "manager"
    when "readers"
      @filter = "reader"
    when "active_teenagers"
      @filter = "active_teenagers" if auditor_signed_in?
    end

    @q = params[:q] || ""

    cookies[:team_view] = params[:view] if params[:view]
    @view = cookies[:team_view] || "grid"

    @all_positions = @event.organizer_positions
                           .joins(:user)
    @all_positions = @all_positions.where(organizer_signed_in? ? "users.full_name ILIKE :query OR users.email ILIKE :query" : "users.full_name ILIKE :query", query: "%#{User.sanitize_sql_like(@q)}%")
                                   .order(created_at: :desc)
    if @filter == "active_teenagers"
      @all_positions = @all_positions.select { |op| op.user.teenager? && op.user.active? } # select if user is a teenager and active (stole from the other code ;))
    elsif @filter
      @all_positions = @all_positions.where(role: @filter)
    end
    @positions = Kaminari.paginate_array(@all_positions).page(params[:page]).per(params[:per] || @view == "list" ? 20 : 10)

    if @event.parent
      ops = @event.ancestor_organizer_positions.includes(:user)
      users = ops.map(&:user).uniq

      access_levels = users.filter_map do |user|
        access_level = user.access_level_for(@event, ops)
        next if access_level[:access_level] == :direct

        [user, access_level[:role]]
      end.sort_by { |_, role| role }.to_h

      @indirect_access = access_levels
    end

    @invites = @event.organizer_position_invites.pending.includes(:sender)
    @invite_requests = @event.organizer_position_invite_requests.pending
    @invite_links = @event.organizer_position_invite_links.active
  end

  # GET /events/1/edit
  def edit
    authorize @event
    if !params[:tab] || !%w[details donations reimbursements card_grants tags affiliations features integrations audit_log admin].include?(params[:tab])
      return redirect_to edit_event_path(@event.slug, tab: "details")
    end

    @settings_tab = params[:tab]
    @frame = params[:frame]
    @activities_before = params[:activities_before] || Time.now
    @activities = PublicActivity::Activity.for_event(@event).before(@activities_before).order(created_at: :desc).page(params[:page]).per(25) if @settings_tab == "audit_log"
    @affiliations = @event.affiliations if @settings_tab == "affiliations"

    CardGrantSetting.find_or_create_by!(event: @event) if @event.plan.card_grants_enabled? && @settings_tab == "card_grants"

    render :edit, layout: !@frame
  end

  # PATCH/PUT /events/1
  def update
    authorize @event

    # have to use `fixed_event_params` because `event_params` seems to be a constant
    fixed_event_params = event_params
    fixed_user_event_params = user_event_params

    # processing hidden for admins
    if fixed_event_params[:hidden] == "1" && !@event.hidden_at.present?
      fixed_event_params[:hidden_at] = DateTime.now
    elsif fixed_event_params[:hidden] == "0" && @event.hidden_at.present?
      fixed_event_params[:hidden_at] = nil
    end
    fixed_event_params.delete(:hidden)

    # processing hidden for users
    if fixed_user_event_params[:hidden] == "1" && !@event.hidden_at.present?
      fixed_user_event_params[:hidden_at] = DateTime.now
    elsif fixed_user_event_params[:hidden] == "0" && @event.hidden_at.present?
      fixed_user_event_params[:hidden_at] = nil
    end
    fixed_user_event_params.delete(:hidden)

    plan_param = fixed_event_params[:plan]
    fixed_event_params.delete(:plan)

    begin
      if @event.update(admin_signed_in? ? fixed_event_params : fixed_user_event_params)
        if plan_param && plan_param != @event.plan&.type
          @event.plan.mark_inactive!(plan_param) # deactivate old plan and replace it
        end


        if @event.description_previously_changed? && @event.description.present?
          announcement = Announcement::Templates::NewMissionStatement.new(
            event: @event,
            author: current_user
          ).create

          flash[:success] = {
            text: "Organization successfully updated.",
            link: edit_announcement_path(announcement),
            link_text: "Create an announcement for your new mission!"
          }
        else
          flash[:success] = "Organization successfully updated."
        end

        redirect_back fallback_location: edit_event_path(@event.slug)
      else
        render :edit, status: :unprocessable_entity
      end
    rescue Errors::InvalidStripeCardLogoError => e
      flash[:error] = e.message
      redirect_back fallback_location: edit_event_path(@event.slug)
    end
  end

  # DELETE /events/1
  def destroy
    authorize @event

    @event.destroy
    flash[:success] = "Organization successfully deleted."
    redirect_to root_path
  end

  def toggle_fee_waiver_eligible
    authorize @event

    @event.update!(fee_waiver_eligible: !@event.fee_waiver_eligible)

    redirect_back fallback_location: event_promotions_path(@event)
  end

  def emburse_card_overview
    authorize @event
    @emburse_cards = @event.emburse_cards.includes(user: [:profile_picture_attachment])
    @emburse_card_requests = @event.emburse_card_requests.includes(creator: :profile_picture_attachment)
    @emburse_transfers = @event.emburse_transfers
    @emburse_transactions = @event.emburse_transactions.order(transaction_time: :desc).where.not(transaction_time: nil).includes(:emburse_card)

    @sum = @event.emburse_balance
  end

  def announcement_overview
    authorize @event

    @announcement = Announcement.new
    @announcement.event = @event

    if organizer_signed_in?
      @all_announcements = Announcement.saved.where(event: @event).order(published_at: :desc, created_at: :desc)
    else
      @all_announcements = Announcement.published.where(event: @event).order(published_at: :desc, created_at: :desc)
    end
    @announcements = @all_announcements.page(params[:page]).per(10)

    @monthly_announcement = Announcement.monthly_for(Date.today).where(event: @event).first
  end

  before_action(only: :feed) { request.format = :atom }

  def feed
    authorize @event
    @announcements = Announcement.published.where(event: @event).includes(:author).order(published_at: :desc, created_at: :desc)
    @updated_at = @announcements.maximum(:updated_at)
  end

  def card_overview
    @status = %w[active inactive frozen canceled].include?(params[:status]) ? params[:status] : nil
    @type = %w[virtual physical].include?(params[:type]) ? params[:type] : nil

    cookies[:card_overview_view] = params[:view] if params[:view]
    @view = cookies[:card_overview_view] || "grid"

    @user = User.friendly.find(params[:user], allow_nil: true) if params[:user]

    @has_filter = @status.present? || @type.present? || @user.present?

    all_stripe_cards = @event.stripe_cards.where.missing(:card_grant).joins(:stripe_cardholder, :user)
                             .order("stripe_status asc, created_at desc")

    all_stripe_cards = all_stripe_cards.where(user: { id: @user.id }) if @user

    all_stripe_cards = case @status
                       when "active"
                         all_stripe_cards.active
                       when "inactive"
                         all_stripe_cards.inactive
                       when "frozen"
                         all_stripe_cards.frozen
                       when "canceled"
                         all_stripe_cards.canceled
                       else
                         all_stripe_cards
                       end

    all_stripe_cards = case @type
                       when "virtual"
                         all_stripe_cards.virtual
                       when "physical"
                         all_stripe_cards.physical
                       else
                         all_stripe_cards
                       end

    if current_user.present?
      @stripe_cards = all_stripe_cards.where.not(stripe_cardholder: current_user.stripe_cardholder)
      @user_stripe_cards = all_stripe_cards.where(stripe_cardholder: current_user.stripe_cardholder)
    else
      @stripe_cards = all_stripe_cards
      @user_stripe_cards = StripeCard.none
    end

    @stripe_cardholders = StripeCardholder.where(user_id: @event.users.pluck(:id)).includes(:user).order("created_at desc")
    @organizer_position = OrganizerPosition.find_by(event: @event, user: current_user)

    authorize @event

    page = (params[:page] || 1).to_i
    per_page = (params[:per] || 18).to_i

    display_cards = [
      @user_stripe_cards.active,
      @stripe_cards.active,
      @user_stripe_cards.deactivated,
      @stripe_cards.deactivated
    ].flatten

    @paginated_stripe_cards = Kaminari.paginate_array(display_cards).page(page).per(per_page)
    @all_unique_cardholders = @event.stripe_cards.on_main_ledger.map(&:stripe_cardholder).uniq
  end

  def documentation
    @event_name = @event.name

    authorize @event
  end

  def async_balance
    authorize @event

    render :async_balance, layout: false
  end

  def async_sub_organization_balance
    authorize @event

    @sub_organizations = filtered_sub_organizations

    render :async_sub_organization_balance, layout: false
  end

  def account_number
    @transactions = if @event.column_account_number.present?
                      CanonicalTransaction.where(transaction_source_type: "RawColumnTransaction", transaction_source_id: RawColumnTransaction.where("column_transaction->>'account_number_id' = '#{@event.column_account_number.column_id}'").pluck(:id)).order(created_at: :desc)
                    else
                      CanonicalTransaction.none
                    end
    page = (params[:page] || 1).to_i
    @transactions = @transactions.page(page).per(params[:per] || 25)
    authorize @event
  end

  def g_suite_overview
    authorize @event

    @g_suite = @event.g_suites.first
    @waitlist_form_submitted = GWaitlistTable.all(filter: "{OrgID} = '#{@event.id}'").any? unless Flipper.enabled?(:google_workspace, @event) || Rails.env.development?

    if @g_suite.present?
      @results = GSuiteService::Verify.new(g_suite_id: @g_suite.id).results(skip_g_verify: true)

      unless @g_suite.verification_error?
        # If we're not in an error state, then we don't want to show the
        # "checklist-style" with the strike-through. Setting the results to false
        # will not strike-through the rows.
        @results = @results.transform_values { false }
      end
    end
  end

  def g_suite_create
    authorize @event

    GSuiteService::Create.new(
      current_user:,
      event_id: @event.id,
      domain: params[:domain]
    ).run

    redirect_to event_g_suite_overview_path(event_id: @event.slug)
  rescue => e
    redirect_to event_g_suite_overview_path(event_id: @event.slug), flash: { error: e.message }
  end

  def g_suite_verify
    authorize @event

    GSuiteService::MarkVerifying.new(g_suite_id: @event.g_suites.first.id).run

    redirect_to event_g_suite_overview_path(event_id: @event.slug)
  end

  def donation_overview
    authorize @event

    # The search query name was historically `search`. It has since been renamed
    # to `q`. This following line retains backwards compatibility.
    params[:q] ||= params[:search]

    relation = @event.donations.not_pending.includes(:recurring_donation)

    @stats = {
      deposited: relation.succeeded_and_not_refunded.sum(:amount),
    }

    @all_donations = relation.succeeded_and_not_refunded

    if params[:filter] == "refunded"
      relation = relation.refunded
    else
      relation = relation.succeeded_and_not_refunded
    end

    relation = relation.search_name(params[:q]) if params[:q].present?

    page = (params[:page] || 1).to_i
    per_page = (params[:per] || DONATIONS_PER_PAGE).to_i

    @all_donations = relation.order(created_at: :desc)

    @recurring_donations = @event.recurring_donations.includes(:donations).active.order(created_at: :desc)

    @donations = Kaminari.paginate_array(@all_donations).page(page).per(per_page)

    @recurring_donations_monthly_sum = @recurring_donations.sum(0) { |donation| donation[:amount] }

  end

  def transfers
    authorize @event

    # The search query name was historically `search`. It has since been renamed
    # to `q`. This following line retains backwards compatibility.
    params[:q] ||= params[:search]

    @ach_transfers = @event.ach_transfers
    @paypal_transfers = @event.paypal_transfers
    @wires = @event.wires
    @wise_transfers = @event.wise_transfers
    @checks = @event.checks.includes(:lob_address)
    @increase_checks = @event.increase_checks
    @disbursements = @event.outgoing_disbursements.includes(:destination_event)

    @disbursements = @disbursements.not_card_grant_related

    @stats = {
      deposited: @ach_transfers.deposited.sum(:amount) + @checks.deposited.sum(:amount) + @increase_checks.deposited.sum(:amount) + @disbursements.fulfilled.pluck(:amount).sum + @paypal_transfers.deposited.sum(:amount_cents) + @wires.deposited.map(&:usd_amount_cents).compact.sum + @wise_transfers.deposited.map(&:usd_amount_cents_or_quoted).compact.sum,
      in_transit: @ach_transfers.in_transit.sum(:amount) + @checks.in_transit_or_in_transit_and_processed.sum(:amount) + @increase_checks.in_transit.sum(:amount) + @disbursements.reviewing_or_processing.sum(:amount) + @paypal_transfers.approved.or(@paypal_transfers.pending).sum(:amount_cents) + @wires.approved.or(@wires.pending).map(&:usd_amount_cents).compact.sum + @wise_transfers.approved.or(@wise_transfers.pending).or(@wise_transfers.sent).map(&:usd_amount_cents_or_quoted).compact.sum,
      canceled: @ach_transfers.rejected.sum(:amount) + @checks.canceled.sum(:amount) + @increase_checks.canceled.sum(:amount) + @disbursements.rejected.sum(:amount) + @paypal_transfers.rejected.sum(:amount_cents) + @wires.rejected.map(&:usd_amount_cents).compact.sum + @wise_transfers.rejected.or(@wise_transfers.failed).map(&:usd_amount_cents_or_quoted).compact.sum
    }

    @ach_transfers = @ach_transfers.in_transit if params[:filter] == "in_transit"
    @ach_transfers = @ach_transfers.deposited if params[:filter] == "deposited"
    @ach_transfers = @ach_transfers.rejected if params[:filter] == "canceled"
    @ach_transfers = @ach_transfers.search_recipient(params[:q]) if params[:q].present?

    @checks = @checks.in_transit_or_in_transit_and_processed if params[:filter] == "in_transit"
    @checks = @checks.deposited if params[:filter] == "deposited"
    @checks = @checks.canceled if params[:filter] == "canceled"
    @checks = @checks.search_recipient(params[:q]) if params[:q].present?

    @increase_checks = @increase_checks.in_transit if params[:filter] == "in_transit"
    @increase_checks = @increase_checks.deposited if params[:filter] == "deposited"
    @increase_checks = @increase_checks.canceled if params[:filter] == "canceled"
    @increase_checks = @increase_checks.search_recipient(params[:q]) if params[:q].present?

    @disbursements = @disbursements.reviewing_or_processing if params[:filter] == "in_transit"
    @disbursements = @disbursements.fulfilled if params[:filter] == "deposited"
    @disbursements = @disbursements.rejected if params[:filter] == "canceled"
    @disbursements = @disbursements.search_name(params[:q]) if params[:q].present?

    @paypal_transfers = @paypal_transfers.approved.or(@paypal_transfers.pending) if params[:filter] == "in_transit"
    @paypal_transfers = @paypal_transfers.deposited if params[:filter] == "deposited"
    @paypal_transfers = @paypal_transfers.rejected if params[:filter] == "canceled"
    @paypal_transfers = @paypal_transfers.search_recipient(params[:q]) if params[:q].present?

    @wires = @wires.approved.or(@wires.pending) if params[:filter] == "in_transit"
    @wires = @wires.deposited if params[:filter] == "deposited"
    @wires = @wires.rejected if params[:filter] == "canceled"
    @wires = @wires.search_recipient(params[:q]) if params[:q].present?

    @wise_transfers = @wise_transfers.approved.or(@wise_transfers.pending).or(@wise_transfers.sent) if params[:filter] == "in_transit"
    @wise_transfers = @wise_transfers.deposited if params[:filter] == "deposited"
    @wise_transfers = @wise_transfers.rejected.or(@wise_transfers.failed) if params[:filter] == "canceled"
    @wise_transfers = @wise_transfers.search_recipient(params[:q]) if params[:q].present?

    @transfers = Kaminari.paginate_array((@increase_checks + @checks + @ach_transfers + @disbursements + @paypal_transfers + @wires + @wise_transfers).sort_by { |o| o.created_at }.reverse!).page(params[:page]).per(100)
  end

  def new_transfer
    authorize @event
  end

  def promotions
    authorize @event

    @active_teenagers_count = @event.users.active_teenager.count

    @perks_available = OrganizerPosition.role_at_least?(current_user, @event, :manager) && !@event.demo_mode? && @event.plan.promotions_enabled?

    # I'm so sorry, this is awful & temporary
    @is_argosy = @event.plan.is_a?(Event::Plan::Argosy2025)
  end

  def reimbursements
    authorize @event
    @total = @event.reimbursement_reports.to_calculate_total.where(currency: "USD").includes(:payout_holding).sum(&:amount_cents)
    @total += Reimbursement::PayoutHolding.where(reimbursement_reports_id: @event.reimbursement_reports.reimbursed.where.not(currency: "USD")).sum(&:amount_cents)
    @total += Money.from_cents(@event.reimbursement_reports.pending.where.not(currency: "USD").sum(&:cached_wise_transfer_quote_amount)).cents
    @reimbursed = Reimbursement::PayoutHolding.where(reimbursement_reports_id: @event.reimbursement_reports.reimbursed).sum(&:amount_cents)
    @pending = @total - @reimbursed

    @reports = @event.reimbursement_reports.visible
    @reports = @reports.draft if params[:status] == "draft"
    @reports = @reports.submitted if params[:status] == "review_required"
    @reports = @reports.reimbursement_requested if params[:status] == "pending"
    @reports = @reports.where(aasm_state: ["reimbursement_approved", "reimbursed"]) if params[:status] == "reimbursed"
    @reports = @reports.rejected if params[:status] == "rejected"
    @reports = @reports.search(params[:q]) if params[:q].present?
    @reports = @reports.where("reimbursement_reports.created_at <= ?", params[:created_before]) if params[:created_before].present?
    @reports = @reports.where("reimbursement_reports.created_at >= ?", params[:created_after]) if params[:created_after].present?
    @reports = @reports.order(created_at: :desc).page(params[:page] || 1).per(params[:per] || 25)

    @filter_options = [
      { key: "status", label: "Status", type: "select", options: %w[draft review_required pending reimbursed rejected] },
      { key: "created_*", label: "Date created", type: "date_range" }
    ]
    @has_filter = helpers.check_filters?(@filter_options, params)
  end

  def reimbursements_pending_review_icon
    authorize @event
    @reimbursements_pending_review_count = @event.reimbursement_reports.submitted.count

    render :reimbursements_pending_review_icon, layout: false
  end

  def employees
    authorize @event
    @employees = @event.employees.order(
      Arel.sql("aasm_state = 'onboarded' DESC"),
      Arel.sql("aasm_state = 'onboarding' DESC"),
      "employees.created_at desc"
    )
    @employees = @employees.onboarding if params[:filter] == "onboarding"
    @employees = @employees.terminated if params[:filter] == "terminated"
    @employees = @employees.search(params[:q]) if params[:q].present?
  end

  def sub_organizations
    authorize @event

    respond_to do |format|
      format.html do
        @sub_organizations = filtered_sub_organizations
      end

      # CSV export intentionally does not consider filters
      format.csv do
        csv = CSV.generate(headers: true) do |csv|
          # We include the public ID because our partners iterate this CSV to
          # access organizations via the V3 API. The public ID serves has a
          # robust, immutable identifier compared to slugs.
          csv << %w[ID Name Slug Balance]

          @event.subevents.find_each do |e|
            csv << [e.public_id, e.name, e.slug, e.balance_v2_cents / 100.0]
          end
        end

        send_data csv, filename: "#{@event.name}'s sub-organizations.csv", type: "text/csv", disposition: :attachment
      end
    end

  end

  def create_sub_organization
    authorize @event

    if params[:email].blank?
      flash[:error] = "Organizer email is required"
      return redirect_back fallback_location: event_sub_organizations_path(@event)
    end

    # Use the current user as POC if they're an admin, otherwise use the system user (bank@hackclub.com)
    poc_id = current_user.admin? ? current_user.id : User.system_user.id

    subevent = ::EventService::Create.new(
      name: params[:name],
      emails: [params[:email]],
      cosigner_email: params[:cosigner_email],
      is_signee: true,
      country: params[:country],
      point_of_contact_id: poc_id,
      invited_by: current_user,
      is_public: @event.is_public,
      plan: @event.config.subevent_plan.presence,
      risk_level: @event.risk_level,
      parent_event: @event,
      scoped_tags: params[:scoped_tags]
    ).run

    redirect_to subevent
  end

  def toggle_hidden
    authorize @event

    if @event.hidden?
      flash[:success] = "Event un-hidden"
      @event.update(hidden_at: nil)
    else
      @event.update(hidden_at: Time.now)
      file_redirects = [
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/a7ce1ae34b9e9422_barking_dog_turned_into_wood_meme.mp4",
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/2d373908baa69206_dog_transforms_after_seeing_chair.mp4",
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/292b3ec8e3ad9fb1_dog_turns_into_bread__but_it_s_in_hd.mp4",
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/b7b400f98e3f264a_run_now_meme.mp4",
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/2cda55c3a53f23b6_bonk_sound_effect.mp4",
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/9a837b44dd082d95_disappearing_doge_meme.mp4"
      ].sample

      redirect_to file_redirects, allow_other_host: true
    end
  end

  def remove_header_image
    authorize @event

    @event.donation_header_image.purge_later

    redirect_back fallback_location: edit_event_path(@event)
  end

  def remove_background_image
    authorize @event

    @event.background_image.purge_later

    redirect_back fallback_location: edit_event_path(@event)
  end

  def remove_logo
    authorize @event

    @event.logo.purge_later

    redirect_back fallback_location: edit_event_path(@event)
  end

  def toggle_event_tag
    @event_tag = EventTag.find(params[:event_tag_id])

    authorize @event
    authorize @event_tag

    if @event.event_tags.where(id: @event_tag.id).exists?
      @event.event_tags.destroy(@event_tag)
    else
      @event.event_tags << @event_tag
    end

    redirect_back fallback_location: edit_event_path(@event, tab: "admin")
  end

  def audit_log
    authorize @event
  end

  def statements
    authorize @event

    @start_date = (@event.activated_at || @event.created_at).beginning_of_month.to_date
    @end_date = Date.today.prev_month.beginning_of_month.to_date
  end

  def statement_of_activity
    authorize @event

    @statement_of_activity = Event::StatementOfActivity.new(
      @event,
      start_date_param: params[:start],
      end_date_param: params[:end],
      include_descendants: ActiveRecord::Type::Boolean.new.cast(params[:include_descendants]),
    )

    respond_to do |format|
      format.html
      format.xlsx do
        send_data(
          @statement_of_activity.xlsx,
          filename: "#{@event.name} - Statement of Activity.xlsx",
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          disposition: "attachment"
        )
      end
    end
  end

  def termination
    authorize @event

    @successor = params[:successor] || "The Hack Foundation"

    @start = params[:start]&.to_datetime || @event.activated_at || @event.created_at

    @end = params[:end]&.to_datetime || Time.now

    respond_to do |format|
      format.html do
        redirect_to @event
      end
      format.pdf do
        render pdf: "Termination Letter for #{@event.name}", page_height: "11in", page_width: "8.5in"
      end
    end
  end

  def validate_slug
    authorize @event

    if params[:value].blank? || params[:value] == @event.slug
      render json: { valid: true }
    elsif @event.tap { |e| e.slug = params[:value] }.valid?
      render json: { valid: true, hint: "This URL is available!" }
    else
      render json: { valid: false, hint: "This URL is unavailable." }
    end
  end

  def activation_flow
    authorize @event
  end

  def activate
    authorize @event

    params[:event][:files]&.each do |file|
      Document.create(user: current_user, event_id: @event.id, name: file.original_filename, file:)
    end

    if event_params[:plan] && event_params[:plan] != @event.plan.type
      @event.plan.mark_inactive!(event_params[:plan]) # deactivate old plan and replace it
    end

    if @event.update(event_params.except(:files, :plan).merge({ demo_mode: false }))
      flash[:success] = "Organization successfully activated."
      redirect_to event_path(@event)
      @event.set_airtable_status("Onboarded")
    else
      render :activation_flow, status: :unprocessable_entity
    end
  end

  def claim_point_of_contact
    authorize @event

    if @event.update(point_of_contact: current_user)
      flash[:success] = "You're now the point of contact for #{@event.name}."
    else
      flash[:error] = "Failed to assign you as point of contact."
    end

    redirect_back fallback_location: edit_event_path(@event.slug)
  end

  def self.filter_transaction_type(type, settled_transactions:, pending_transactions:)
    # Be careful! This is used by the v4 API so beware of breaking changes.
    type_filters = {
      "ach_transfer"           => {
        "settled" => ->(t) { t.local_hcb_code.ach_transfer? },
        "pending" => ->(t) { t.raw_pending_outgoing_ach_transaction_id }
      },
      "mailed_check"           => {
        "settled" => ->(t) { t.local_hcb_code.check? || t.local_hcb_code.increase_check? },
        "pending" => ->(t) { t.raw_pending_outgoing_check_transaction_id || t.increase_check_id }
      },
      "hcb_transfer"           => {
        "settled" => ->(t) { t.local_hcb_code.disbursement? && !t.local_hcb_code.disbursement.destination_subledger_id && !t.local_hcb_code.disbursement.source_subledger_id },
        "pending" => ->(t) { t.local_hcb_code.disbursement? && !t.local_hcb_code.disbursement.destination_subledger_id && !t.local_hcb_code.disbursement.source_subledger_id }
      },
      "card_charge"            => {
        "settled" => ->(t) { t.raw_stripe_transaction },
        "pending" => ->(t) { t.raw_pending_stripe_transaction_id }
      },
      "check_deposit"          => {
        "settled" => ->(t) { t.local_hcb_code.check_deposit? },
        "pending" => ->(t) { t.check_deposit_id }
      },
      "donation"               => {
        "settled" => ->(t) { t.local_hcb_code.donation? },
        "pending" => ->(t) { t.raw_pending_donation_transaction_id }
      },
      "invoice"                => {
        "settled" => ->(t) { t.local_hcb_code.invoice? },
        "pending" => ->(t) { t.raw_pending_invoice_transaction_id }
      },
      "refund"                 => {
        "settled" => ->(t) { t.local_hcb_code.stripe_refund? },
        "pending" => ->(t) { false }
      },
      "fiscal_sponsorship_fee" => {
        "settled" => ->(t) { t.local_hcb_code.fee_revenue? || t.fee_payment? },
        "pending" => ->(t) { t.raw_pending_bank_fee_transaction_id }
      },
      "reimbursement"          => {
        "settled" => ->(t) { t.local_hcb_code.reimbursement_expense_payout? },
        "pending" => ->(t) { false }
      },
      "wire"                   => {
        "settled" => ->(t) { t.local_hcb_code.wire? },
        "pending" => ->(t) { t.wire_id }
      },
      "paypal_transfer"        => {
        "settled" => ->(t) { t.local_hcb_code.paypal_transfer? },
        "pending" => ->(t) { t.paypal_transfer_id }
      },
      "wise_transfer"          => {
        "settled" => ->(t) { t.local_hcb_code.wise_transfer? },
        "pending" => ->(t) { t.wise_transfer_id }
      }
    }

    if type
      filter = type_filters[type]
      if filter
        settled_transactions = settled_transactions.select(&filter["settled"])
        pending_transactions = pending_transactions.select(&filter["pending"])
      end
    end

    { settled_transactions:, pending_transactions: }
  end

  def merchants_filter
    authorize @event

    @merchant = params[:merchant]

    merchants_hash = {}

    @event.merchants.each do |merchant|
      if merchants_hash.key?(merchant[:id])
        merchants_hash[merchant[:id]][:count] = merchants_hash[merchant[:id]][:count] + 1
      else
        merchants_hash[merchant[:id]] = { name: merchant[:name], count: 1 }
      end
    end

    @merchants = merchants_hash.map { |id, merchant| { id:, name: merchant[:name], count: merchant[:count] } }.sort_by { |merchant| merchant[:count] }.reverse!.first(30)
  end

  private

  def filtered_sub_organizations(sub_organizations = @event.subevents)
    search = params[:q] || params[:search]
    scoped_tag = Event::ScopedTag.find_by(name: params[:tag])

    relation = sub_organizations.includes(:scoped_tags, :parent, logo_attachment: :blob, background_image_attachment: :blob, organizer_positions: :user)
    relation = relation.where("name ILIKE ?", "%#{search}%") if search.present?
    relation = relation.joins(:scoped_tags).where("event_scoped_tags.id = #{scoped_tag.id}") if scoped_tag.present?
    relation = relation.order(created_at: :desc)

    @filter_options = [
      { key: "tag", label: "Tag", type: "select", options: @event.subevent_scoped_tags.map(&:name) }
    ]
    @has_filter = helpers.check_filters?(@filter_options, params)

    relation
  end

  # Only allow a trusted parameter "white list" through.
  def event_params
    permitted_params = [
      :name,
      :short_name,
      :description,
      :start,
      :end,
      :address,
      :demo_mode,
      :can_front_balance,
      :emburse_department_id,
      :country,
      :postal_code,
      :risk_level,
      :point_of_contact_id,
      :slug,
      :hidden,
      :donation_page_enabled,
      :donation_page_message,
      :donation_tiers_enabled,
      :reimbursements_require_organizer_peer_review,
      :public_reimbursement_page_enabled,
      :public_reimbursement_page_message,
      :donation_thank_you_message,
      :donation_reply_to_email,
      :is_public,
      :is_indexable,
      :holiday_features,
      :public_message,
      :donation_header_image,
      :logo,
      :website,
      :background_image,
      :stripe_card_logo,
      :stripe_card_shipping_type,
      :plan,
      :financially_frozen,
      {
        card_grant_setting_attributes: [
          :merchant_lock,
          :category_lock,
          :keyword_lock,
          :invite_message,
          :banned_merchants,
          :banned_categories,
          :expiration_preference,
          :reimbursement_conversions_enabled,
          :pre_authorization_required
        ],
        config_attributes: [
          :id,
          :anonymous_donations,
          :cover_donation_fees,
          :contact_email,
          :generate_monthly_announcement,
          :subevent_plan
        ]
      }
    ]

    if Flipper.enabled?(:parent_event_assignment_2025_09_18, current_user)
      permitted_params << :parent_id
    end

    result_params = params.require(:event).permit(*permitted_params)

    # convert whatever the user inputted into something that is a legal slug
    result_params[:slug] = ActiveSupport::Inflector.parameterize(user_event_params[:slug]) if result_params[:slug]

    result_params
  end

  def user_event_params
    result_params = params.require(:event).permit(
      :short_name,
      :description,
      :address,
      :slug,
      :hidden,
      :start,
      :end,
      :donation_page_enabled,
      :donation_page_message,
      :donation_tiers_enabled,
      :reimbursements_require_organizer_peer_review,
      :public_reimbursement_page_enabled,
      :public_reimbursement_page_message,
      :donation_thank_you_message,
      :donation_reply_to_email,
      :is_public,
      :is_indexable,
      :holiday_features,
      :public_message,
      :donation_header_image,
      :logo,
      :website,
      :background_image,
      :stripe_card_logo,
      card_grant_setting_attributes: [
        :merchant_lock,
        :category_lock,
        :keyword_lock,
        :invite_message,
        :banned_merchants,
        :banned_categories,
        :expiration_preference,
        :reimbursement_conversions_enabled,
        :pre_authorization_required
      ],
      config_attributes: [
        :id,
        :anonymous_donations,
        :cover_donation_fees,
        :contact_email,
        :generate_monthly_announcement
      ]
    )

    # convert whatever the user inputted into something that is a legal slug
    result_params[:slug] = ActiveSupport::Inflector.parameterize(result_params[:slug]) if result_params[:slug]

    result_params
  end

  def set_transaction_filters
    # The search query name was historically `search`. It has since been renamed
    # to `q`. This following line retains backwards compatibility.
    params[:q] ||= params[:search]

    if params[:tag]
      @tag = Tag.find_by(event_id: @event.id, label: params[:tag])
    end

    @user = @event.users.friendly.find(params[:user], allow_nil: true) if params[:user]

    @type = params[:type]
    @start_date = params[:start].presence
    @end_date = params[:end].presence
    @minimum_amount = params[:minimum_amount].presence ? Money.from_amount(params[:minimum_amount].to_f) : nil
    @maximum_amount = params[:maximum_amount].presence ? Money.from_amount(params[:maximum_amount].to_f) : nil
    @missing_receipts = params[:missing_receipts].present?
    @merchant = params[:merchant]
    @direction = params[:direction]
    @category = TransactionCategory.find_by(slug: params[:category])

    # Also used in Transactions page UI (outside of Ledger)
    @organizers = @event.organizer_positions.joins(:user).includes(user: { profile_picture_attachment: :blob }).order(Arel.sql("CONCAT(preferred_name, full_name) ASC"))

    if @merchant
      merchant = @event.merchants.find { |merchant| merchant[:id] == @merchant }

      @merchant_name = merchant.present? ? merchant[:name] : "Merchant #{@merchant}"
    end

    @ledger_filters_disabled = !(organizer_signed_in? || auditor_signed_in?)
    has_filters = @tag || @user || @type || @start_date || @end_date || @minimum_amount || @maximum_amount || @missing_receipts || @merchant || @direction || @category
    if @ledger_filters_disabled && has_filters
      render plain: "Invalid parameters. Please try again", status: :bad_request
    end
  end

  def _show_pending_transactions
    return [] if params[:page] && params[:page] != "1"
    return [] if params[:direction]

    pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(
      event_id: @event.id,
      search: params[:q],
      tag_id: @tag&.id,
      minimum_amount: @minimum_amount,
      maximum_amount: @maximum_amount,
      revenue: @direction == "revenue",
      expenses: @direction == "expenses",
      user: @user,
      start_date: @start_date,
      end_date: @end_date,
      missing_receipts: @missing_receipts,
      category: @category,
      merchant: @merchant,
      order_by: @order_by&.to_sym || "date",
      subledger: params[:subledger]
    ).run
    PendingTransactionEngine::PendingTransaction::AssociationPreloader.new(pending_transactions:, event: @event).run!
    pending_transactions
  end

  def show_running_balance?
    # don't support running balance if tag or search query are present because these filter the query of all transactions, which
    # breaks the running balance computation
    return false if @tag.present?
    return false if params[:q].present?

    @show_running_balance = auditor_signed_in? && current_user.running_balance_enabled?
  end

  def set_cacheable
    has_filters = !(
      params[:q].blank? &&
        params[:page].blank? &&
        params[:per].blank? &&
        @user.nil? &&
        @tag.blank? &&
        @type.blank? &&
        @start_date.blank? &&
        @end_date.blank? &&
        @minimum_amount.nil? &&
        @maximum_amount.nil? &&
        @direction.nil? &&
        @category.nil? &&
        @merchant.nil? &&
        !@missing_receipts
    )

    @cacheable = !(organizer_signed_in? || has_filters)
  end

  def set_timeframe
    @timeframe = BreakdownEngine::TIMEFRAMES[params[:timeframe]]
  end

  def set_event_follow
    @event_follow = Event::Follow.where({ user_id: current_user.id, event_id: @event.id }).first if current_user
  end

  def serialize_event(event, member:)
    {
      name: event.name,
      slug: event.slug,
      logo: event.logo.attached? ? Rails.application.routes.url_helpers.url_for(event.logo) : "none",
      demo_mode: event.demo_mode,
      member:,
      features: {
        subevents: event.subevents_enabled?,
        card_grants: event.plan.card_grants_enabled?
      }
    }
  end

end
