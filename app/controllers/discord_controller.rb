# frozen_string_literal: true

require "ed25519"
require "discordrb"

class DiscordController < ApplicationController
  protect_from_forgery except: [:webhook, :interaction]
  skip_before_action :signed_in_user, only: [:webhook, :interaction]
  before_action :verify_discord_signature, only: [:webhook, :interaction]
  skip_after_action :verify_authorized

  def webhook
    # Webhook event where the bot was added to a server
    if (params[:type] = 1) && (params[:event][:type] = "APPLICATION_AUTHORIZED") && params[:event][:data][:integration_type] = 0
      user_id = params[:event][:data][:user][:id]

      channel = bot.pm_channel(user_id)
      bot.send_message(channel, "Welcome to HCB! Link your Discord account to your HCB account by going to #{discord_link_url(discord_id: user_id)}")
    end

    head :no_content
  end

  def interaction
    puts "Received Discord interaction"

    if params[:type] == 1
      puts "Responding to PING"
      render json: { type: 1 } and return
    end

    if params[:type] == 2
      command_name = params[:data][:name]
      if command_name.in?(::Discord::RegisterCommandsJob.commands.pluck(:name))
        return send("#{command_name}_command")
      end

      render json: { type: 4, data: { content: "Unknown command" } } and return
    end

    Rails.error.unexpected "🚨 Unknown payload received from Discord on interaction webhook: #{params.inspect}"
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
    @bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)
  end

  def verify_discord_signature
    timestamp = request.headers["X-Signature-Timestamp"]
    signature_hex = request.headers["X-Signature-Ed25519"]
    signature = [signature_hex].pack("H*")
    key = [Credentials.fetch(:DISCORD__PUBLIC_KEY)].pack("H*")

    verify_key = Ed25519::VerifyKey.new(key)

    begin
      verify_key.verify(signature, timestamp + request.raw_post)
    rescue Ed25519::VerifyError
      head :unauthorized
      return
    end
  end

  def ping_command
    render json: { type: 4, data: { content: "Pong!" } } and return
  end

  def link_command
    render json: { type: 4, data: { content: "The /link command is currently under construction" } } and return
  end

  def balance_command
    render json: { type: 4, data: { content: "Your balance: $67,000" } } and return
  end

  def transactions_command

  end

  def reimburse_command

  end

end
