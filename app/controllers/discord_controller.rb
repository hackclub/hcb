# frozen_string_literal: true

require "ed25519"
require "discordrb"

class DiscordController < ApplicationController
  protect_from_forgery except: :webhook
  skip_before_action :signed_in_user, only: :webhook
  skip_after_action :verify_authorized

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

    # Webhook event where the bot was added to a server
    if (params[:type] = 1) && (params[:event][:type] = "APPLICATION_AUTHORIZED") && params[:event][:data][:integration_type] = 0
      user_id = params[:event][:data][:user][:id]

      channel = bot.pm_channel(user_id)
      bot.send_message(channel, "Welcome to HCB! Link your Discord account to your HCB account by going to #{discord_link_url(discord_id: user_id)}")
    end

    head :no_content
  end

  def link
    @discord_id = params[:discord_id]

    @discord_user = bot.user(@discord_id)
  end

  def create_link
    current_user.update!(discord_id: params[:discord_id])

    flash[:success] = "Successfully linked Discord account"
    redirect_to root_path
  end

  private

  def bot
    @bot ||= Discordrb::Bot.new token: ENV["DISCORD_BOT_TOKEN"]
  end

end
