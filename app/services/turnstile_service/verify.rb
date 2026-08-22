# frozen_string_literal: true

require "net/http"

module TurnstileService
  # Validates a `cf-turnstile-response` token against Cloudflare's siteverify
  # endpoint. See
  # https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
  class Verify
    SITEVERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

    # Cloudflare documents tokens as at most 2048 characters. Anything longer
    # isn't ours, so drop it rather than spending a request on it.
    MAX_TOKEN_LENGTH = 2048

    # Deliberately short: someone is sitting in a modal waiting on this.
    TIMEOUT = 5

    def initialize(token:, action:, hostname:, remote_ip: nil)
      @token = token
      @action = action
      @hostname = hostname
      @remote_ip = remote_ip
    end

    def run
      # A token arriving as an array or hash is someone poking at us, not a
      # solved widget.
      return false unless @token.is_a?(String)
      return false if @token.blank? || @token.length > MAX_TOKEN_LENGTH

      result = siteverify
      return false unless result
      return false unless result["success"] == true

      # `action` and `hostname` are recorded when the widget is solved and
      # returned to us here. Without checking them, a token solved on any other
      # form — or on any other site sharing our sitekey — would pass.
      result["action"] == @action && result["hostname"] == @hostname
    end

    private

    def siteverify
      response = Net::HTTP.start(
        SITEVERIFY_URL.hostname,
        SITEVERIFY_URL.port,
        use_ssl: true,
        open_timeout: TIMEOUT,
        read_timeout: TIMEOUT
      ) do |http|
        request = Net::HTTP::Post.new(SITEVERIFY_URL)
        request.set_form_data(
          {
            secret: TurnstileService.secret_key,
            response: @token,
            remoteip: @remote_ip
          }.compact
        )
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.error.unexpected("[Turnstile] siteverify returned #{response.code}")
        return nil
      end

      JSON.parse(response.body)
    rescue => e
      # Failing to reach Cloudflare fails the check closed; the user can retry.
      Rails.error.report(e)
      nil
    end

  end
end
