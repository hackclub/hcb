# frozen_string_literal: true

class TwilioController < ActionController::Base
  protect_from_forgery except: :webhook

  def webhook
    Twilio::ProcessWebhookJob.perform_later(webhook_params: webhook_params.to_h)

    respond_to do |format|
      format.xml { render xml: "<Response></Response>" }
    end
  end

  private

  def webhook_params
    params.permit(:From, :To, :Body, :NumMedia, *media_params)
  end

  def media_params
    num_media = params["NumMedia"].to_i
    (0...num_media).flat_map { |i| ["MediaUrl#{i}", "MediaContentType#{i}"] }
  end

end
