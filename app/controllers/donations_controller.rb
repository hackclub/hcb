# frozen_string_literal: true

require "csv"

class DonationsController < ApplicationController
  include SetEvent
  include Rails::Pagination

  skip_after_action :verify_authorized, except: [:start_donation, :make_donation]
  skip_before_action :signed_in_user
  before_action :set_donation, only: [:show]
  before_action :set_event, only: [:start_donation, :make_donation, :qr_code]

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
    if !@event.donation_page_enabled
      return not_found
    end

    if @event.demo_mode?
      @example_event = Event.find(183)
    end

    @donation = Donation.new(amount: params[:amount], event: @event)

    authorize @donation
  end

  def make_donation
    d_params = public_donation_params
    d_params[:amount] = Monetize.parse(public_donation_params[:amount]).cents

    @donation = Donation.new(d_params)
    @donation.event = @event

    authorize @donation

    if @donation.save
      redirect_to finish_donation_donations_path(@event, @donation.url_hash)
    else
      render "start_donation"
    end
  end

  def finish_donation

    @donation = Donation.find_by!(url_hash: params["donation"])

    # We don't use set_event here to prevent a UI vulnerability where a user could create a donation on one org and make it look like another org by changing the slug
    # https://github.com/hackclub/bank/issues/3197
    @event = @donation.event

    if @donation.status == "succeeded"
      flash[:info] = "You tried to access the payment page for a donation that’s already been sent."
      redirect_to start_donation_donations_path(@event)
    end
  end

  def accept_donation_hook
    payload = request.body.read
    sig_header = request.headers['Stripe-Signature']
    event = nil

    begin
      event = StripeService.construct_webhook_event(payload, sig_header, :donations)
    rescue Stripe::SignatureVerificationError
      head 400
      return
    end

    # only proceed if payment intent is a donation and not an invoice
    return unless event.data.object.metadata[:donation].present?

    # get donation to process
    donation = Donation.find_by_stripe_payment_intent_id(event.data.object.id)

    pi = StripeService::PaymentIntent.retrieve(
      id: donation.stripe_payment_intent_id,
      expand: ["charges.data.balance_transaction"]
    )
    donation.set_fields_from_stripe_payment_intent(pi)
    donation.save!

    DonationService::Queue.new(donation_id: donation.id).run # queues/crons payout. DEPRECATE. most is unnecessary if we just run in a cron

    donation.send_receipt!

    # Import the donation onto the ledger
    rpdt = ::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::ImportSingle.new(donation: donation).run
    cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation.new(raw_pending_donation_transaction: rpdt).run
    ::PendingEventMappingEngine::Map::Single::Donation.new(canonical_pending_transaction: cpt).run

    return true
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

    ::DonationJob::Refund.perform_later(@donation.id)

    redirect_to hcb_code_path(@hcb_code.hashid), flash: { success: "The refund process has been queued for this donation." }
  end

  def export
    @event = Event.friendly.find(params[:event])

    authorize @event.donations.first

    respond_to do |format|
      format.csv { stream_donations_csv }
      format.json { stream_donations_json }
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

  def set_donation
    @donation = Donation.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def donation_params
    params.require(:donation).permit(:email, :name, :amount, :amount_received, :status, :stripe_client_secret)
  end

  def public_donation_params
    params.require(:donation).permit(:email, :name, :amount, :message)
  end

  def redirect_to_404
    raise ActionController::RoutingError.new("Not Found")
  end

end
