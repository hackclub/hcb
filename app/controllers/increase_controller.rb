# frozen_string_literal: true

class IncreaseController < ApplicationController
  protect_from_forgery except: :webhook # Ignore CSRF checks
  skip_after_action :verify_authorized, only: :webhook # Do not force pundit
  skip_before_action :signed_in_user, only: :webhook # Do not require logged in user

  def webhook
    payload = request.body.read
    sig_header = request.headers["Increase-Webhook-Signature"]

    Increase::Webhook::Signature.verify(
      payload:,
      signature_header: sig_header,
      secret: signing_secret
    )

    head :ok # It's a valid webhook!

    # Send to event category-specific handler
    method = "handle_#{params[:category].gsub(/\W/, "_")}"
    if self.respond_to?(method, :include_private)
      self.send method, params.to_unsafe_h # we trust Increase 🤞
    end

  rescue Increase::WebhookSignatureVerificationError => e
    Rails.error.report(e)

    render json: { error: "Webhook signature verification failed" }, status: :bad_request
  end

  private

  def handle_check_transfer_updated(event)
    increase_check = Increase::CheckTransfers.retrieve event["associated_object_id"]
    IncreaseCheck.find_by(increase_id: increase_check["id"])&.update!(
      increase_status: increase_check["status"],
      check_number: increase_check["check_number"],
      increase_object: increase_check,
    )
  end

  def signing_secret
    Rails.application.credentials.dig(:increase, IncreaseService.environment, :webhook_secret)
  end

end
