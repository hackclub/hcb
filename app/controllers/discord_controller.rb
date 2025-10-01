# frozen_string_literal: true

require "ed25519"

class DiscordController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def webhook
    timestamp = request.headers["X-Signature-Timestamp"]
    signature_hex = request.headers["X-Signature-Ed25519"]
    signature = [signature_hex].pack("H*")
    key = [ENV["DISCORD_PUBLIC_KEY"]].pack("H*")

    verify_key = Ed25519::VerifyKey.new(key)

    begin
      verify_key.verify(signature, timestamp + request.raw_post)
    rescue Ed25519::VerifyError
      head :unauthorized
      return
    end

    head :no_content
  end

end
