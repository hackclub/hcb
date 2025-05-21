# frozen_string_literal: true

class HcbCodesController < ApplicationController
  include TagsHelper

  skip_before_action :signed_in_user, only: [:receipt, :attach_receipt, :show]
  skip_after_action :verify_authorized, only: [:receipt]

  def show
    @hcb_code = HcbCode.find_by(hcb_code: params[:id]) || HcbCode.find(params[:id])
    @event =
      begin
        # Attempt to retrieve the event using the context of the
        # previous page. Has a high chance of erroring, but we'll give it
        # a shot.
        route = Rails.application.routes.recognize_path(request.referrer)
        model = route[:controller].classify.constantize
        object = model.find(route[:id])
        event = model == Event ? object : object.event
        raise StandardError unless @hcb_code.events.include?(event) && current_user.events.include?(event)

        event
      rescue
        @hcb_code.events.min_by do |e|
          e.users.include?(current_user) ? 0 : 1
        end
      rescue
        @hcb_code.event
      end

    hcb = @hcb_code.hcb_code
    hcb_id = @hcb_code.hashid

    authorize @hcb_code

    return not_found if @hcb_code.unused?

    if params[:show_details] == "true" && @hcb_code.ach_transfer?
      ahoy.track "ACH details shown", hcb_code_id: @hcb_code.id
      @show_ach_details = true
    end

    if params[:frame]
      @frame = true
      @transaction_show_receipt_button = params[:transaction_show_receipt_button].nil? ? false : params[:transaction_show_receipt_button]
      @transaction_show_author_img = params[:transaction_show_author_img].nil? ? false : params[:transaction_show_author_img]

      render :show, layout: false
    else
      @frame = false
      render :show
    end
  rescue Pundit::NotAuthorizedError => e
    if @hcb_code.stripe_card.card_grant.present? && current_user == @hcb_code.stripe_card.card_grant.user
      redirect_to card_grant_path(@hcb_code.stripe_card.card_grant, frame: params[:frame])
    else
      raise unless @event.is_public? && !params[:redirect_to_sign_in]

      if @hcb_code.canonical_transactions.any?
        txs = TransactionGroupingEngine::Transaction::All.new(event_id: @event.id).run
        pos = txs.index { |tx| tx.hcb_code == hcb } + 1
        page = (pos.to_f / EventsController::TRANSACTIONS_PER_PAGE).ceil

        redirect_to event_path(@event, page:, anchor: hcb_id)
      else
        redirect_to event_path(@event, anchor: hcb_id)
      end
    end
  end

  def memo_frame
    @hcb_code = HcbCode.find(params[:id])
    authorize @hcb_code
  end

  def edit
    @hcb_code = HcbCode.find_by(hcb_code: params[:id]) || HcbCode.find(params[:id])
    @event = @hcb_code.event
    @ai_memo = params[:display_ai_memo] == "true" ? @hcb_code.suggested_memos.last : nil

    authorize @hcb_code

    if params[:inline].present?
      return render partial: "hcb_codes/memo", locals: { hcb_code: @hcb_code, form: true, prepended_to_memo: params[:prepended_to_memo], location: params[:location], ledger_instance: params[:ledger_instance] }
    end

    @frame = turbo_frame_request?
    @suggested_memos = ::HcbCodeService::SuggestedMemos.new(hcb_code: @hcb_code, event: @event).run.first(4)
  end

  def pin
    @hcb_code = HcbCode.find(params[:id])
    param_event = Event.friendly.find_by_friendly_id(params[:event])
    @event = param_event ? @hcb_code.events.find_by(id: param_event.id) : @hcb_code.event

    authorize @hcb_code
    authorize @event

    # Handle unpinning
    if (@pin = HcbCode::Pin.find_by(event: @event, hcb_code: @hcb_code))
      @pin.destroy
      flash[:success] = "Unpinned transaction from #{@event.name}"
      redirect_back fallback_location: @event and return
    end

    # Handle pinning
    @pin = HcbCode::Pin.new(event: @event, hcb_code: @hcb_code)
    if @pin.save
      flash[:success] = "Transaction pinned!"
    else
      flash[:error] = @pin.errors.full_messages.to_sentence
    end

    redirect_back fallback_location: @event
  end

  def update
    @hcb_code = HcbCode.find_by(hcb_code: params[:id]) || HcbCode.find(params[:id])

    authorize @hcb_code
    hcb_code_params = params.require(:hcb_code).permit(:memo, :prepended_to_memo, :location, :ledger_instance)
    hcb_code_params[:memo] = hcb_code_params[:memo].presence

    @hcb_code.canonical_transactions.each { |ct| ct.update!(custom_memo: hcb_code_params[:memo]) }
    @hcb_code.canonical_pending_transactions.each { |cpt| cpt.update!(custom_memo: hcb_code_params[:memo]) }

    if params[:hcb_code][:inline].present?
      return render partial: "hcb_codes/memo", locals: { hcb_code: @hcb_code, form: false, prepended_to_memo: params[:hcb_code][:prepended_to_memo], location: params[:hcb_code][:location], ledger_instance: params[:hcb_code][:ledger_instance], renamed: true }
    end

    redirect_to @hcb_code
  end

  def comment
    @hcb_code = HcbCode.find(params[:id])

    authorize @hcb_code

    ::HcbCodeService::Comment::Create.new(
      hcb_code_id: @hcb_code.id,
      content: params[:content],
      file: params[:file],
      admin_only: params[:admin_only],
      current_user:
    ).run

    redirect_to params[:redirect_url]
  rescue => e
    redirect_to params[:redirect_url], flash: { error: e.message }
  end

  include HcbCodeHelper # for disputed_transactions_airtable_form_url and attach_receipt_url

  def attach_receipt
    @hcb_code = HcbCode.find(params[:id])
    @event = @hcb_code.event
    @secret = params[:s]

    authorize @hcb_code

  rescue Pundit::NotAuthorizedError
    raise unless HcbCode.find_signed(@secret, purpose: :receipt_upload) == @hcb_code
  end

  def send_receipt_sms
    @hcb_code = HcbCode.find(params[:id])

    authorize @hcb_code

    cpt = @hcb_code.canonical_pending_transactions.first

    if cpt
      CanonicalPendingTransaction::SendTwilioReceiptMessageJob.perform_now(cpt_id: cpt.id, user_id: current_user.id)
      flash[:success] = "SMS queued for delivery!"
    else
      flash[:error] = "This transaction doesn't support SMS notifications."
    end

    redirect_back fallback_location: @hcb_code
  end

  def dispute
    @hcb_code = HcbCode.find(params[:id])

    authorize @hcb_code

    can_dispute, error_reason = ::HcbCodeService::CanDispute.new(hcb_code: @hcb_code).run

    if can_dispute
      redirect_to disputed_transactions_airtable_form_url(embed: false, hcb_code: @hcb_code, user: @current_user), allow_other_host: true
    else
      redirect_to @hcb_code, flash: { error: error_reason }
    end
  end

  def toggle_tag
    hcb_code = HcbCode.find(params[:id])
    tag = Tag.find(params[:tag_id])
    @event = tag.event

    authorize hcb_code
    authorize tag

    raise Pundit::NotAuthorizedError unless hcb_code.events.include?(tag.event)

    removed = false

    if hcb_code.tags.exists?(tag.id)
      removed = true
      hcb_code.tags.destroy(tag)
    else
      hcb_code.tags << tag
    end

    respond_to do |format|
      format.turbo_stream do
        if removed
          render partial: "tags/destroy", locals: { hcb_code:, tag: }
        else
          render partial: "tags/create", locals: { hcb_code:, tag: }
        end
      end
      format.any { redirect_back fallback_location: @event }
    end
  end

  def invoice_as_personal_transaction
    hcb_code = HcbCode.find(params[:id])
    event = hcb_code.event

    authorize hcb_code

    if hcb_code.amount_cents >= -100
      flash[:error] = "Invoices can only be generated for charges of $1.00 or more."
      return redirect_to hcb_code
    end

    if hcb_code.personal_transaction
      flash[:error] = "A repayment invoice already exists for this transaction."
      return redirect_to hcb_code.personal_transaction.invoice
    end

    personal_tx = HcbCode::PersonalTransaction.create(hcb_code:, reporter: current_user)

    flash[:success] = "We've sent an invoice for repayment to #{personal_tx.invoice.sponsor.contact_email}."

    redirect_to personal_tx.invoice
  end

end
