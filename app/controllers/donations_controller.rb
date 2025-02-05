# frozen_string_literal: true

require "csv"

class DonationsController < ApplicationController
  include SetEvent
  include Rails::Pagination

  skip_after_action :verify_authorized, only: [:export, :show, :qr_code, :finish_donation, :finished]
  skip_before_action :signed_in_user
  before_action :set_donation, only: [:show]
  before_action :set_event, only: [:start_donation, :make_donation, :qr_code, :export, :export_donors]
  before_action :check_dark_param
  before_action :check_background_param
  before_action :hide_seasonal_decorations
  skip_before_action :redirect_to_onboarding

  # Rationale: the session doesn't work inside iframes (because of third-party cookies)
  skip_before_action :verify_authenticity_token, only: [:start_donation, :make_donation, :finish_donation]

  # Allow embedding donation pages inside iframes
  content_security_policy(only: [:start_donation, :make_donation, :finish_donation]) do |policy|
    policy.frame_ancestors "*"
  end

  permissions_policy do |p|
    # Allow stripe.js to wrap PaymentRequest in non-safari browsers.
    p.payment    :self
    # Allow embedded donation pages to be fullscreened
    p.fullscreen :self
  end

  invisible_captcha only: [:make_donation], honeypot: :subtitle, on_timestamp_spam: :redirect_to_404

  # GET /donations/1
  def show
    authorize @donation
    @hcb_code = HcbCode.find_or_create_by(hcb_code: @donation.hcb_code)
    redirect_to hcb_code_path(@hcb_code.hashid)
  end

  def start_donation
    unless @event.donation_page_available?
      return not_found
    end

    tax_deductible = params[:goods].nil? ? true : params[:goods] == "0"

    @donation = Donation.new(
      name: params[:name] || (organizer_signed_in? ? nil : current_user&.name),
      email: params[:email] || (organizer_signed_in? ? nil : current_user&.email),
      amount: params[:amount],
      message: params[:message],
      fee_covered: params[:fee_covered],
      event: @event,
      ip_address: request.ip,
      user_agent: request.user_agent,
      tax_deductible:,
      referrer: request.referrer,
      utm_source: params[:utm_source],
      utm_medium: params[:utm_medium],
      utm_campaign: params[:utm_campaign],
      utm_term: params[:utm_term],
      utm_content: params[:utm_content]
    )

    authorize @donation

    @monthly = params[:monthly].present?

    if @monthly
      @recurring_donation = @event.recurring_donations.build(
        name: params[:name],
        email: params[:email],
        amount: params[:amount],
        message: params[:message],
        fee_covered: params[:fee_covered],
        tax_deductible:
      )
    end

    @placeholder_amount = "%.2f" % (DonationService::SuggestedAmount.new(@event, monthly: @monthly).run / 100.0)

    @hide_flash = true
  end

  def make_donation
    d_params = donation_params
    d_params[:amount] = Monetize.parse(donation_params[:amount]).cents

    if d_params[:fee_covered] == "1" && @event.config.cover_donation_fees
      d_params[:amount] = (d_params[:amount] / (1 - @event.revenue_fee)).ceil
    end

    if d_params[:name] == "aser ras"
      skip_authorization
      redirect_to root_url and return
    end

    d_params[:ip_address] = request.ip
    d_params[:user_agent] = request.user_agent

    tax_deductible = d_params[:goods].nil? ? true : d_params[:goods] == "0"

    @donation = Donation.new(d_params.except(:goods).merge({ tax_deductible: }))
    @donation.event = @event

    authorize @donation

    if @donation.save
      redirect_to finish_donation_donations_path(@event, @donation.url_hash, background: @background)
    else
      render :start_donation, status: :unprocessable_entity
    end
  end

  def finish_donation

    @donation = Donation.find_by!(url_hash: params["donation"])

    # We don't use set_event here to prevent a UI vulnerability where a user could create a donation on one org and make it look like another org by changing the slug
    # https://github.com/hackclub/hcb/issues/3197
    @event = @donation.event

    if @donation.status == "succeeded"
      flash[:info] = "You tried to access the payment page for a donation that’s already been sent."
      redirect_to start_donation_donations_path(@event)
    end

    if cookies[:donation_dark]
      cookies.delete(:donation_dark)
    end
  end

  def finished
    @donation = Donation.find_by!(url_hash: params[:donation])
    @event = @donation.event
  end

  def qr_code
    qrcode = RQRCode::QRCode.new(start_donation_donations_url(@event))

    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 2,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: "black",
      fill: "white",
      module_px_size: 6,
      size: 300
    )

    send_data png, filename: "#{@event.name} Donate.png",
      type: "image/png", disposition: "inline"
  end

  def refund
    @donation = Donation.find(params[:id])
    @hcb_code = @donation.local_hcb_code

    authorize @donation

    if @donation.canonical_transactions.any?
      ::DonationService::Refund.new(donation_id: @donation.id, amount: Monetize.parse(params[:amount]).cents).run
      redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "The refund process has been queued for this donation." }
    else
      DonationJob::Refund.set(wait: 1.day).perform_later(@donation, Monetize.parse(params[:amount]).cents)
      redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "This donation hasn't settled, it's being queued to refund when it settles." }
    end
  end

  def export
    authorize @event.donations.first

    respond_to do |format|
      format.csv { stream_donations_csv }
      format.json { stream_donations_json }
    end
  end

  def export_donors
    authorize @event.donations.first

    respond_to do |format|
      format.csv { stream_donors_csv }
    end
  end

  private

  def stream_donations_csv
    set_file_headers_csv
    set_streaming_headers

    response.status = 200

    self.response_body = donations_csv
  end

  def stream_donations_json
    set_file_headers_json
    set_streaming_headers

    response.status = 200

    self.response_body = donations_json
  end

  def stream_donors_csv
    set_file_headers_csv
    headers["Content-disposition"] = "attachment; filename=donors.csv"
    set_streaming_headers

    response.status = 200

    self.response_body = donors_csv
  end

  def set_file_headers_csv
    headers["Content-Type"] = "text/csv"
    headers["Content-disposition"] = "attachment; filename=donations.csv"
  end

  def set_file_headers_json
    headers["Content-Type"] = "application/json"
    headers["Content-disposition"] = "attachment; filename=donations.json"
  end

  def donations_csv
    ::DonationService::Export::Csv.new(event_id: @event.id).run
  end

  def donations_json
    ::DonationService::Export::Json.new(event_id: @event.id).run
  end

  def donors_csv
    ::DonationService::Export::Donors::Csv.new(event_id: @event.id).run
  end

  def set_donation
    @donation = Donation.find(params[:id])
  end

  def check_dark_param
    if params[:dark].present? || cookies[:donation_dark]
      @dark = true
      cookies[:donation_dark] = true
    end
  end

  def check_background_param
    # because we're going to be injecting this value into a stylesheet,
    # we ensure that it's a hex code to prevent: https://css-tricks.com/css-security-vulnerabilities/
    @background = params[:background] unless (params[:background] =~ /\A[0-9a-fA-F]{6}\z/).nil?
  end

  def hide_seasonal_decorations
    @hide_seasonal_decorations = true
  end

  def donation_params
    params.require(:donation).permit(:email, :name, :amount, :message, :anonymous, :goods, :fee_covered, :referrer, :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content)
  end

  def redirect_to_404
    raise ActionController::RoutingError.new("Not Found")
  end

end
