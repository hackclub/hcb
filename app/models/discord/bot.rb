module Discord
  module Bot
    def self.bot
      @bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)
    end

    def self.verify_webhook_signature(request)
      timestamp = request.headers["X-Signature-Timestamp"]
      signature_hex = request.headers["X-Signature-Ed25519"]
      signature = [signature_hex].pack("H*")
      key = [Credentials.fetch(:DISCORD__PUBLIC_KEY)].pack("H*")

      verify_key = Ed25519::VerifyKey.new(key)

      return true if verify_key.verify(signature, timestamp + request.raw_post)
    rescue => e
      Rails.error.report(e)
      false
    end

    def self.install_link
      "https://discord.com/oauth2/authorize?client_id=#{Credentials.fetch(:DISCORD__APPLICATION_ID)}"
    end
  end
end
