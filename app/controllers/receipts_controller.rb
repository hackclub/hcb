# frozen_string_literal: true

class ReceiptsController < ApplicationController
  skip_after_action :verify_authorized, only: :create # do not force pundit
  skip_before_action :signed_in_user, only: :create
  before_action :set_paper_trail_whodunnit, only: :create
  before_action :find_receiptable, only: [:create, :link, :link_modal]
  before_action :set_event, only: [:create, :link]
  before_action :set_transaction_display_data
  before_action :set_receipt, only: [:destroy, :reverse]

  def destroy
    @receiptable = @receipt.receiptable
    authorize @receipt

    success = @receipt.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        if params[:popover]&.starts_with?("HcbCode:")
          flash[:popover] = params[:popover].gsub("HcbCode:", "")
        end

        if success
          flash[:success] = "Deleted receipt"
          redirect_back fallback_location: @receiptable || my_inbox_path
        else
          flash[:error] = "Failed to delete receipt"
          redirect_back fallback_location: @receiptable || my_inbox_path
        end
      }
    end
  end

  def link
    params.require(:receipt_id)
    params.require(:receiptable_type)
    params.require(:receiptable_id)

    @receipt = Receipt.find(params[:receipt_id])

    authorize @receipt
    authorize @receiptable, policy_class: ReceiptablePolicy

    @receipt.update!(receiptable: @receiptable)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        if params[:show_link]
          flash[:success] = { text: "Receipt linked!", link: (hcb_code_path(@receiptable) if @receiptable.instance_of?(HcbCode)), link_text: "View" }
        else
          flash[:success] = "Receipt added!"
        end

        if params[:popover]&.starts_with?("HcbCode:")
          flash[:popover] = params[:popover].gsub("HcbCode:", "")
        end

        if params[:redirect_url]
          redirect_to params[:redirect_url]
        else
          redirect_back fallback_location: @receiptable.try(:hcb_code) || @receiptable
        end
      }
    end
  end

  def link_modal
    authorize @receiptable, policy_class: ReceiptablePolicy

    @receipts = Receipt.in_receipt_bin.with_attached_file.where(user: current_user).order(created_at: :desc)
    @show_link = params[:show_link]
    @streams = defined?(params[:streams]) ? params[:streams] : true
    @suggested_receipt_ids = []

    if params[:popover].present?
      @popover = params[:popover]
    end

    if @receiptable.instance_of?(HcbCode)
      pairings_sql = <<~SQL
        LEFT JOIN (#{@receiptable.suggested_pairings.to_sql}) sp
        ON sp.receipt_id = receipts.id
      SQL
      @receipts = @receipts.joins(pairings_sql).reorder("sp.distance ASC, receipts.created_at DESC")
      @suggested_receipt_ids = @receipts.limit(3).where("sp.distance <= ?", 1000).pluck(:id)
    end

    render :link_modal, layout: false

  end

  def create
    streams = []

    file_param = params[:ledger_instance].present? ? "file_#{params[:ledger_instance]}" : "file"
    params.require(file_param)
    params.require(:upload_method)

    begin
      if @receiptable
        authorize @receiptable, :upload?, policy_class: ReceiptablePolicy
      end
    rescue Pundit::NotAuthorizedError
      raise unless @receiptable.is_a?(HcbCode) && HcbCode.find_signed(params[:s], purpose: :receipt_upload) == @receiptable
    end

    return unless params[file_param].present?

    streams = []

    params[file_param].map do |file|
      (receipt, ) = ::ReceiptService::Create.new(
        receiptable: @receiptable,
        uploader: current_user,
        attachments: [file],
        upload_method: params[:upload_method]
      ).run!
      next if @receiptable && !on_transaction_page?

      streams.append(turbo_stream.prepend(
                       @ledger_instance.present? ? "#{@ledger_instance}_receipts_list" : "receipts_list",
                       partial: "receipts/receipt",
                       locals: { receipt:, show_delete_button: true, show_reimbursements_button: true, show_receipt_bin_button: true, link_to_file: true, turbo_for_deletion: true }
                     ))
    end

    if %w[transaction_popover transaction_popover_drag_and_drop].include?(params[:upload_method])
      @frame = true
    end

    streams += generate_streams

    unless @receiptable && [:receipts_page, "receipts_page_drag_and_drop"].include?(params[:upload_method])
      receipt_upload_form_config = {
        upload_method: params[:upload_method].sub("_drag_and_drop", ""),
        restricted_dropzone: params[:upload_method] != :transaction_page,
        include_spacing: params[:upload_method] != :receipt_center,
        success: "#{"Receipt".pluralize(params[file_param].length)} added!",
        global_paste: !@receiptable,
        turbo: true
      }
      if @receiptable
        receipt_upload_form_config[:enable_linking] = true
        receipt_upload_form_config[:receiptable] = @receiptable
      end
      if @receiptable && @frame && on_transaction_page?
        receipt_upload_form_config[:restricted_dropzone] = true
        receipt_upload_form_config[:inline_linking] = true
        receipt_upload_form_config[:upload_method] = "transaction_popover"
        receipt_upload_form_config[:popover] = "HcbCode:#{@receiptable.hashid}"
        receipt_upload_form_config[:show_receipt_button] = @show_receipt_button
        receipt_upload_form_config[:show_author_img] = @show_author_img
      end
      streams.append(
        turbo_stream.replace(@receiptable ? "#{@receiptable.id}_receipt_upload_form" : :receipt_upload_form, partial: "receipts/form_v3", locals: receipt_upload_form_config)
      )
    end

    flash_type = :success
    if params[:show_link]
      flash_message = { text: "#{"Receipt".pluralize(params[file_param].length)} added!", link: (hcb_code_path(@receiptable) if @receiptable.instance_of?(HcbCode)), link_text: "View" }
    else
      flash_message = "#{"Receipt".pluralize(params[file_param].length)} added!"
    end

  rescue => e
    Rails.error.report(e) unless e.is_a?(ActiveRecord::RecordInvalid)

    flash_type = :error
    flash_message = "There was an error uploading your receipt. Please try again."

    streams.append(
      turbo_stream.replace(
        :receipt_upload_form,
        partial: "receipts/form_v3", locals: {
          upload_method: "receipt_center",
          restricted_dropzone: true,
          error: e.message
        }
      )
    )
  ensure
    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html         {
        flash[flash_type] = flash_message if flash_message && flash_type
        if params[:redirect_url]
          redirect_to params[:redirect_url]
        elsif @receiptable.is_a?(HcbCode) && @receiptable.stripe_card&.card_grant.present?
          redirect_to @receiptable.stripe_card.card_grant
        else
          if params[:popover]&.starts_with?("HcbCode:")
            flash[:popover] = params[:popover].gsub("HcbCode:", "")
          end

          redirect_back fallback_location: URI.parse(@receiptable&.try(:url) || url_for(@receiptable) || my_inbox_path)
        end
      }
    end
  end

  def reverse
    authorize @receipt
    @receiptable = @receipt.receiptable

    if @receipt.suggested_pairings.accepted.any?
      pairing = @receipt.suggested_pairings.accepted.first
      success = pairing.mark_reversed!
    else
      success = @receipt.update(receiptable: nil)
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: generate_streams }
      format.html         {
        if params[:popover]&.starts_with?("HcbCode:")
          flash[:popover] = params[:popover].gsub("HcbCode:", "")
        end

        if success
          flash[:success] = {
            text: "Moved receipt to your",
            link: my_inbox_path,
            link_text: "receipt bin"
          }
          redirect_back fallback_location: @receiptable || my_inbox_path
        else
          flash[:error] = "Failed to move receipt to your receipt bin"
          redirect_back fallback_location: @receiptable || my_inbox_path
        end
      }
    end
  end

  private

  RECEIPTABLE_TYPE_MAP = [HcbCode, CanonicalTransaction, Transaction, StripeAuthorization,
                          EmburseTransaction, Reimbursement::Expense, Reimbursement::Expense::Mileage,
                          Reimbursement::Expense::Fee, Api::Models::CardCharge, Ledger::Item].index_by(&:to_s).freeze

  def find_receiptable
    return unless params[:receiptable_type].present?
    return unless params[:receiptable_id].present?
    return unless RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]

    @klass = RECEIPTABLE_TYPE_MAP[params[:receiptable_type]]
    @receiptable = @klass.find(params[:receiptable_id])
  end

  def generate_streams
    streams = []

    if current_user
      streams.append(
        turbo_stream.replace(
          "suggested_pairings",
          partial: "static_pages/suggested_pairings",
          locals: { pairings: current_user.receipt_bin.suggested_receipt_pairings, current_slide: 0 }
        )
      )
      streams.append(
        turbo_stream.replace(
          "receipts_blankslate",
          partial: "receipts/blankslate", locals: {
            count: Receipt.in_receipt_bin.where(user: current_user).count
          }
        )
      )
    end

    if @receiptable.is_a?(HcbCode)
      @hcb_code = @receiptable

      if @receiptable.canonical_transactions&.any?
        @receiptable.canonical_transactions.each do |ct|
          streams.append(turbo_stream.remove("transaction_details_#{ct.__id__}"))
          streams.append(turbo_stream.replace(
                           ct.local_hcb_code.hashid,
                           partial: "canonical_transactions/canonical_transaction",
                           locals: @frame && @event ? { ct:, event: @event, show_amount: true, updated_via_turbo_stream: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_tags: on_transaction_page? } : { ct:, event: @hcb_code.event, force_display_details: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_event_name: true, updated_via_turbo_stream: true, show_tags: on_transaction_page? }
                         ))
        end
      else
        @receiptable.canonical_pending_transactions&.each do |pt|
          streams.append(turbo_stream.remove("transaction_details_#{pt.__id__}"))
          streams.append(turbo_stream.replace(
                           pt.local_hcb_code.hashid,
                           partial: "canonical_pending_transactions/canonical_pending_transaction",
                           locals: @frame && @event ? { pt:, event: @event, show_amount: true, updated_via_turbo_stream: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_tags: on_transaction_page? } : { pt:, event: @hcb_code.event, force_display_details: true, show_author_column: @show_author_img, receipt_upload_button: @show_receipt_button, show_event_name: true, updated_via_turbo_stream: true, show_tags: on_transaction_page? }
                         ))
        end
      end
    end

    if @receiptable.is_a?(Reimbursement::Expense)
      streams.append(
        turbo_stream.replace(
          "receipts_for_#{@receiptable.id}",
          partial: "reimbursement/expenses/receipts", locals: {
            expense: @receiptable
          }
        )
      )
      streams.append(
        turbo_stream.replace(
          "action-wrapper",
          partial: "reimbursement/reports/actions",
          locals: { report: @receiptable.report, user: @receiptable.report.user }
        )
      )
    end

    if @receiptable.is_a?(HcbCode) && on_transaction_page? && !@receiptable.stripe_refund?
      streams.append(
        turbo_stream.replace(
          "#{@ledger_instance}_stripe_card_receipts",
          partial: "hcb_codes/stripe_card_receipts",
        )
      )

      streams.append(
        turbo_stream.replace(
          "#{@ledger_instance}_receipts_list",
          partial: "receipts/list_v2",
          locals: { hcb_code: @hcb_code, frame: @frame, transaction_show_receipt_button: @show_receipt_button, transaction_show_author_img: @show_author_img }
        )
      )
    end

    if @receipt && on_transaction_page?
      streams.append(turbo_stream.append(
                       :receipts_list,
                       partial: "receipts/receipt",
                       locals: { receipt: @receipt, show_delete_button: true, show_receipt_bin_button: true, link_to_file: true }
                     ))
    elsif @receipt
      streams.append(turbo_stream.remove("receipt_#{@receipt.id}"))
    end

    if @receipt
      if @frame
        streams.append(turbo_stream.remove("modal_receipt_#{@receipt.id}"))
      else
        streams.append(turbo_stream.remove("receipt_#{@receipt.id}"))
      end
    end

    unless params[:upload_method] == :transaction_page
      streams.append(turbo_stream.refresh_link_modals)
    end

    streams
  end

  def set_event
    route = Rails.application.routes.recognize_path(request.referrer)
    return unless route[:controller].classify == "Event"

    @event = Event.friendly.find(route[:id]) rescue nil
  end

  def set_receipt
    @receipt = Receipt.find(params[:id])
  end

  def on_transaction_page?
    route = Rails.application.routes.recognize_path(request.referrer)
    return route[:controller].classify == "HcbCode"
  end

  def set_transaction_display_data
    @frame = params[:popover].present?
    @show_receipt_button = params[:show_receipt_button] == "true"
    @show_author_img = params[:show_author_img] == "true"
    @ledger_instance = params[:ledger_instance]
  end

end
