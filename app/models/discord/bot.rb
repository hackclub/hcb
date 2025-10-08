module Discord
  module Bot
    def self.bot
      @bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)
    end
  end
end
