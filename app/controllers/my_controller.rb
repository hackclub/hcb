# frozen_string_literal: true

class MyController < ApplicationController
  skip_after_action :verify_authorized, only: [:activities, :toggle_admin_activities, :cards, :missing_receipts_list, :missing_receipts_icon, :inbox, :reimbursements, :reimbursements_icon, :tasks, :payroll, :feed] # do not force pundit

  before_action :set_reimbursement_reports, only: [:reimbursements, :reimbursements_icon]

  def activities
    @before = params[:before] || Time.now
    if auditor_signed_in? && cookies[:admin_activities] == "everyone"
      @activities = PublicActivity::Activity.all.before(@before).order(created_at: :desc).page(params[:page]).per(25)
    else
      @activities = PublicActivity::Activity.for_user(current_user).before(@before).order(created_at: :desc).page(params[:page]).per(25)
    end
  end

  def toggle_admin_activities
    cookies[:admin_activities] = cookies[:admin_activities] == "everyone" ? "myself" : "everyone"
    redirect_to my_activities_url
  end

  def cards
    @stripe_cards = current_user.stripe_cards.includes(:event)
    @emburse_cards = current_user.emburse_cards.includes(:event)

    @status = params[:status].presence_in(%w[active inactive frozen canceled])
    @type = params[:type].presence_in(%w[virtual physical])
    @filter_applied = @status || @type

    @stripe_cards = case @status
                    when "active"
                      @stripe_cards.active
                    when "inactive"
                      @stripe_cards.inactive
                    when "frozen"
                      @stripe_cards.frozen
                    when "canceled"
                      @stripe_cards.canceled
                    else
                      @stripe_cards
                    end

    @stripe_cards = case @type
                    when "virtual"
                      @stripe_cards.virtual
                    when "physical"
                      @stripe_cards.physical
                    else
                      @stripe_cards
                    end

    @stripe_cards = @stripe_cards.order(
      Arel.sql("stripe_status = 'active' DESC"),
      Arel.sql("stripe_status = 'inactive' DESC")
    )
  end

  def tasks
    @tasks = current_user.tasks
    respond_to do |format|
      format.html
      format.json { render json: { count: @tasks.count } }
    end
  end

  def missing_receipts_list
    @missing = current_user.transactions_missing_receipt

    if @missing.any?
      render :missing_receipts_list, layout: !request.xhr?
    else
      head :ok
    end
  end

  def missing_receipts_icon
    count = current_user.transactions_missing_receipt.count

    emojis = {
      "🤡": 300,
      "💀": 200,
      "😱": 100
    }

    @missing_receipt_count = count
    @missing_receipt_emoji = emojis.find { |emoji, value| count >= value }&.first

    render :missing_receipts_icon, layout: false
  end

  def inbox
    @count = current_user.transactions_missing_receipt.count
    @locking_count = current_user.transactions_missing_receipt(from: Receipt::CARD_LOCKING_START_DATE, to: 24.hours.ago).count

    hcb_code_ids_missing_receipt = current_user.hcb_code_ids_missing_receipt

    @time_based_sorting = hcb_code_ids_missing_receipt.count > (params[:per] || 15).to_i

    hcb_codes_missing_receipt = HcbCode.where(id: hcb_code_ids_missing_receipt)
                                       .includes(:canonical_transactions, canonical_pending_transactions: :raw_pending_stripe_transaction) # HcbCode#card uses CT and PT
                                       .index_by(&:id).slice(*hcb_code_ids_missing_receipt).values

    if @time_based_sorting
      hcb_codes_missing_receipt = hcb_codes_missing_receipt.sort_by(&:created_at).reverse
    end

    @hcb_codes = Kaminari.paginate_array(hcb_codes_missing_receipt)
                         .page(params[:page]).per(params[:per] || 15)

    unless @time_based_sorting
      @card_hcb_codes = @hcb_codes.group_by { |hcb| hcb.card.to_global_id.to_s }.transform_values { |v| v.sort_by(&:created_at).reverse }
      @cards = GlobalID::Locator.locate_many(@card_hcb_codes.keys, includes: :event)
                                # Order cards by created_at, newest first
                                .sort_by(&:created_at).reverse!
    end

    @mailbox_address = current_user.active_mailbox_address
    @receipts = Receipt.in_receipt_bin.with_attached_file.where(user: current_user)
    @pairings = current_user.receipt_bin.suggested_receipt_pairings

    if flash[:popover]
      @popover = flash[:popover]
      flash.delete(:popover)
    end
  end

  def reimbursements
    case params[:filter]
    when "mine"
      @reports = @my_reports
    when "review"
      @reports = @reports_to_review
    else
      @reports = @my_reports.or(@reports_to_review)
    end

    @reports = @reports.search(params[:q]) if params[:q].present?

    @payout_method = current_user.payout_method
  end

  def reimbursements_icon
    @reports_count = @my_reports.draft.or(@reports_to_review).count

    render :reimbursements_icon, layout: false
  end

  def payroll
    @jobs = current_user.jobs
    @payout_method = current_user.payout_method
  end

  def feed
    @event_follows = current_user.event_follows
    @all_announcements = Announcement.published.where(event: @event_follows.map(&:event)).order(published_at: :desc, created_at: :desc)
    @announcements = @all_announcements.page(params[:page]).per(10)
  end

  private

  def set_reimbursement_reports
    @my_reports = current_user.reimbursement_reports
    manager_events = current_user.events
                                 .joins(:organizer_positions)
                                 .where(organizer_positions: { user_id: current_user.id, role: :manager })
    @reports_to_review = Reimbursement::Report.submitted.where(event: manager_events, reviewer_id: nil).or(current_user.assigned_reimbursement_reports.submitted)
  end

end
