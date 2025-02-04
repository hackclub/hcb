# frozen_string_literal: true

class MyController < ApplicationController
  skip_after_action :verify_authorized, only: [:activities, :toggle_admin_activities, :cards, :missing_receipts_list, :missing_receipts_icon, :inbox, :reimbursements, :reimbursements_icon, :tasks] # do not force pundit

  def activities
    @before = params[:before] || Time.now
    if admin_signed_in? && cookies[:admin_activities] == "everyone"
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
    @stripe_cards = current_user.stripe_cards.includes(:event).order(
      Arel.sql("stripe_status = 'active' DESC"),
      Arel.sql("stripe_status = 'inactive' DESC")
    )
    @emburse_cards = current_user.emburse_cards.includes(:event)

    @active_stripe_cards = @stripe_cards.where.not(stripe_status: "canceled")
    @canceled_stripe_cards = @stripe_cards.where(stripe_status: "canceled")
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
      "🤡 ": 300,
      "💀 ": 200,
      "😱 ": 100,
    }

    @missing_receipt_count = "#{emojis.find { |emoji, value| count >= value }&.first}#{count}"

    render :missing_receipts_icon, layout: false
  end

  def inbox
    @count = current_user.transactions_missing_receipt.count
    hcb_code_ids_missing_receipt = current_user.hcb_code_ids_missing_receipt
    @hcb_codes = Kaminari.paginate_array(HcbCode.where(id: hcb_code_ids_missing_receipt)
                 .includes(:canonical_transactions, canonical_pending_transactions: :raw_pending_stripe_transaction) # HcbCode#card uses CT and PT
                 .index_by(&:id).slice(*hcb_code_ids_missing_receipt).values)
                         .page(params[:page]).per(params[:per] || 15)

    @card_hcb_codes = @hcb_codes.group_by { |hcb| hcb.card.to_global_id.to_s }
    @cards = GlobalID::Locator.locate_many(@card_hcb_codes.keys, includes: :event)
                              # Order by cards with least transactions first
                              .sort_by { |card| @card_hcb_codes[card.to_global_id.to_s].count }

    if Flipper.enabled?(:receipt_bin_2023_04_07, current_user)
      @mailbox_address = current_user.active_mailbox_address
      @receipts = Receipt.in_receipt_bin.with_attached_file.where(user: current_user)
      @pairings = current_user.receipt_bin.suggested_receipt_pairings
    end

    if flash[:popover]
      @popover = flash[:popover]
      flash.delete(:popover)
    end
  end

  def reimbursements
    @my_reports = current_user.reimbursement_reports
    @my_reports = @my_reports.search(params[:q]) if params[:q].present?
    @reports_to_review = Reimbursement::Report.submitted.where(event: current_user.events, reviewer_id: nil).or(current_user.assigned_reimbursement_reports.submitted)
    @payout_method = current_user.payout_method
  end

  def reimbursements_icon
    @draft_reimbursements_count = current_user.reimbursement_reports.draft.count
    @review_requested_reimbursements_count = current_user.assigned_reimbursement_reports.submitted.count

    render :reimbursements_icon, layout: false
  end

end
