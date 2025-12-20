# frozen_string_literal: true

module Discord
  MESSAGE_EXPIRATION = 15.minutes
  extend Discord::Support

  def self.table_name_prefix
    "discord_"
  end

  def self.generate_signed(content, **kwargs)
    options = { expires_in: MESSAGE_EXPIRATION }.merge(kwargs)
    message_verifier.generate(content, **options)
  end

  def self.verify_signed(...) = message_verifier.verify(...)

  def self.message_verifier
    @message_verifier ||= Rails.application.message_verifier("discord")
  end

  def self.random_avatar
    "https://cdn.discordapp.com/embed/avatars/#{Random.rand(6)}.png"
  end
end
