# frozen_string_literal: true

class InvoicesController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :new, :create]
  skip_before_action :signed_in_user

  def index
    authorize @event, :invoices?
    relation = @event.invoices

    # The search query name was historically `search`. It has since been renamed
    # to `q`. This following line retains backwards compatibility.
    params[:q] ||= params[:search]

    # from events controller
    @invoices_in_transit = (relation.paid_v2.where(payout_id: nil)
      .where
      .not(payout_creation_queued_for: nil) +
      @event.invoices.joins(:payout)
      .where(invoice_payouts: { status: "in_transit" })
      .or(@event.invoices.joins(:payout).where(invoice_payouts: { status: "pending" })))
    amount_in_transit = @invoices_in_transit.sum(&:amount_paid)
    archived_unpaid = relation.unpaid.archived.sum(:item_amount)
    voided = relation.void_v2.sum(:item_amount)

    @stats = {
      # The calcluations for `total` and `unpaid` do not include archived invoices
      total: relation.sum(:item_amount) - archived_unpaid - voided,
      # "paid" status invoices include manually paid invoices and
      # Stripe invoices that are paid, but for which the funds are in transit
      paid: relation.paid_v2.sum(:item_amount) - amount_in_transit,
      pending: amount_in_transit,
      unpaid: relation.unpaid.sum(:item_amount) - archived_unpaid,
    }

    case params[:status]
    when "paid"
      relation = relation.paid_v2
    when "unpaid"
      relation = relation.unpaid
    when "archived"
      relation = relation.archived
    when "voided"
      relation = relation.void_v2
    else
      relation = relation.unarchived
    end

    relation = relation.where("item_amount >= ?", params[:amount_greater_than].to_i * 100) if params[:amount_greater_than].present?
    relation = relation.where("item_amount <= ?", params[:amount_less_than].to_i * 100) if params[:amount_less_than].present?
    relation = relation.where("invoices.created_at >= ?", params[:created_after]) if params[:created_after].present?
    relation = relation.where("invoices.created_at <= ?", params[:created_before]) if params[:created_before].present?

    relation = relation.search_description(params[:q]) if params[:q].present?

    @invoices = relation.order(created_at: :desc)

    @sponsor = Sponsor.new(event: @event)
    @invoice = Invoice.new(sponsor: @sponsor, event: @event)

    @filter_options = filter_options
    helpers.validate_filter_options(@filter_options, params)
    @has_filter = helpers.check_filters?(@filter_options, params)
  end

  def new
    @sponsor = Sponsor.new(event: @event)
    @invoice = Invoice.new(sponsor: @sponsor, event: @event)

    authorize @invoice
  end

  def create
    authorize @event, policy_class: InvoicePolicy

    sponsor_attrs = filtered_params[:sponsor_attributes]

    due_date = Date.parse(filtered_params["due_date"])

    @invoice = ::InvoiceService::Create.new(
      event_id: @event.id,
      due_date:,
      item_description: filtered_params[:item_description],
      item_amount: filtered_params[:item_amount],
      current_user:,

      sponsor_id: sponsor_attrs[:id],
      sponsor_name: sponsor_attrs[:name],
      sponsor_email: sponsor_attrs[:contact_email],
      sponsor_address_line1: sponsor_attrs[:address_line1],
      sponsor_address_line2: sponsor_attrs[:address_line2],
      sponsor_address_city: sponsor_attrs[:address_city],
      sponsor_address_state: sponsor_attrs[:address_state],
      sponsor_address_postal_code: sponsor_attrs[:address_postal_code],
      sponsor_address_country: sponsor_attrs[:address_country]
    ).run

    flash[:success] = "Invoice successfully created and emailed to #{@invoice.sponsor.contact_email}."

    redirect_to @invoice
  rescue Pundit::NotAuthorizedError
    raise
  rescue => e
    Rails.error.report(e)

    @sponsor = Sponsor.new(event: @event)
    @invoice = Invoice.new(sponsor: @sponsor)

    redirect_to new_event_invoice_path(@event), flash: { error: e.message }
  end

  def show
    @invoice = Invoice.friendly.find(params[:id])
    authorize @invoice
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @invoice.hcb_code)
    redirect_to hcb_code_path(@hcb_code.hashid)
  end

  def archive
    @invoice = Invoice.friendly.find(params[:invoice_id])

    authorize @invoice

    @invoice.archived_at = DateTime.now
    @invoice.archived_by = current_user

    if @invoice.save
      redirect_to @invoice
    else
      flash[:error] = "Something went wrong while trying to archive this invoice!"
      redirect_to @invoice
    end
  end

  def void
    @invoice = Invoice.friendly.find(params[:invoice_id])

    authorize @invoice

    ::InvoiceService::MarkVoid.new(invoice_id: @invoice.id, user: current_user).run

    redirect_to @invoice
  end

  def unarchive
    @invoice = Invoice.friendly.find(params[:invoice_id])

    authorize @invoice

    @invoice.archived_at = nil
    @invoice.archived_by = nil

    if @invoice.save
      flash[:success] = "Invoice has been un-archived."
      redirect_to @invoice
    else
      flash[:error] = "Something went wrong while trying to archive this invoice!"
      redirect_to @invoice
    end
  end

  def hosted
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice

    @invoice.sync_remote!
    @invoice.reload

    redirect_to URI.parse(@invoice.hosted_invoice_url).to_s, allow_other_host: true
  end

  def pdf
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice

    @invoice.sync_remote!
    @invoice.reload

    redirect_to URI.parse(@invoice.invoice_pdf).to_s, allow_other_host: true
  end

  def refund
    @invoice = Invoice.find(params[:id])
    @hcb_code = @invoice.local_hcb_code

    authorize @invoice

    if @invoice.canonical_transactions.any?
      ::InvoiceService::Refund.new(invoice_id: @invoice.id, amount: Monetize.parse(params[:amount]).cents).run
      redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "The refund process has been queued for this invoice." }
    else
      Invoice::RefundJob.set(wait: 1.day).perform_later(@invoice, Monetize.parse(params[:amount]).cents, current_user)
      redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "This invoice hasn't settled, it's being queued to refund when it settles." }
    end
  end

  def manually_mark_as_paid
    @invoice = Invoice.friendly.find(params[:invoice_id])
    @hcb_code = @invoice.local_hcb_code

    authorize @invoice

    ::InvoiceService::MarkVoid.new(invoice_id: @invoice.id, user: current_user).run

    @invoice.update(manually_marked_as_paid_at: Time.now, manually_marked_as_paid_user: current_user, manually_marked_as_paid_reason: params[:manually_marked_as_paid_reason])

    redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "Manually marked this invoice as paid." }
  end

  private

  def filtered_params
    params.require(:invoice).permit(
      :due_date,
      :item_description,
      :item_amount,
      :sponsor_id,
      sponsor_attributes: policy(Sponsor).permitted_attributes
    )
  end

  def filter_options
    min_amount = @event.invoices.minimum(:item_amount) || 0
    max_amount = @event.invoices.maximum(:item_amount) || 0

    [
      { key: "status", label: "Status", type: "select", options: %w[paid unpaid archived voided] },
      { key_base: "created", label: "Date", type: "date_range" },
      { key_base: "amount", label: "Amount", type: "amount_range", range: [min_amount / 100, max_amount / 100] }
    ]
  end

end
