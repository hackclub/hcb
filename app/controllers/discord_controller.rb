# frozen_string_literal: true

class DiscordController < ApplicationController
  protect_from_forgery except: [:event_webhook, :interaction_webhook]
  skip_before_action :signed_in_user, only: [:event_webhook, :interaction_webhook]
  before_action :verify_discord_signature, only: [:event_webhook, :interaction_webhook]
  skip_after_action :verify_authorized, only: [:event_webhook, :interaction_webhook, :link]

  def event_webhook
    if params[:type] == 0
      # This is Discord's health check on our server. No need to do anything besides return a 204.
      # If type is 1, then it's an event we need to handle.
      head :no_content
      return
    end
    # Webhook event where the bot was added to a server
    # `event.data.interaction_type`:
    #   - `0`: Bot was added to server
    #   - `1`: Bot was added to user
    if (params[:event][:type] == "APPLICATION_AUTHORIZED") && params[:event][:data][:integration_type] == 0
      user_id = params[:event][:data][:user][:id]

      channel = bot.pm_channel(user_id)
      bot.send_message(channel, "Welcome to HCB! Link your Discord account to your HCB account by going to #{discord_link_url(discord_id: user_id)}")
    end

    head :no_content
  end

  def interaction_webhook
    puts "Received Discord interaction"

    if params[:type] == 1 # PING
      puts "Responding to PING"
      render json: { type: 1 }

    elsif params[:type] == 2 # application command
      render json: { type: 5 } # Acknowledge interaction & will edit response later
      ::Discord::HandleInteractionJob.perform_later(params.to_unsafe_h)

    else
      Rails.error.unexpected "🚨 Unknown payload received from Discord on interaction webhook: #{params.inspect}"
    end
  end

  def link
    @discord_id = params[:discord_id]
    authorize nil, policy_class: DiscordPolicy

    conn = Faraday.new url: "https://discord.com" do |c|
      c.request :json
      c.request :authorization, "Bot", -> { Credentials.fetch(:DISCORD__BOT_TOKEN) }
      c.response :json
      c.response :raise_error
    end

    response = conn.get("/api/v10/users/#{@discord_id}")

    @raw_response = response.body

    @discord_user = bot.user(@discord_id)
  end

  def create_link
    current_user.update!(discord_id: params[:discord_id])

    flash[:success] = "Successfully linked Discord account"
    redirect_to root_path
  end

  def setup
    @guild_id = params[:guild_id]
    @channel_id = params[:channel_id]
    authorize nil, policy_class: DiscordPolicy

    conn = Faraday.new url: "https://discord.com" do |c|
      c.request :json
      c.request :authorization, "Bot", -> { Credentials.fetch(:DISCORD__BOT_TOKEN) }
      c.response :json
      c.response :raise_error
    end

    ch_response = conn.get("/api/v10/channels/#{@channel_id}")

    @raw_ch_response = ch_response.body

    gd_response = conn.get("/api/v10/guilds/#{@guild_id}")

    @raw_gd_response = gd_response.body
  end

  def create_server_link
    event = Event.find(params[:event_id])
    authorize event, policy_class: DiscordPolicy


    event.update!(discord_guild_id: params[:guild_id], discord_channel_id: params[:channel_id])

    bot.send_message(params[:channel_id], "The HCB organization #{event.name} has been successfully linked to this Discord server! Notifications and announcements will be sent in this channel, <\##{params[:channel_id]}>.")
    flash[:success] = "Successfully linked the organization #{event.name} to your Discord server"
    redirect_to root_path
  rescue => e
    Rails.error.report("Exception linking discord server: #{e}")
    flash[:error] = "We could not link the selected organization to your Discord server"
    redirect_to root_path
  end

  def unlink_server
    @guild_id = params[:guild_id]

    conn = Faraday.new url: "https://discord.com" do |c|
      c.request :json
      c.request :authorization, "Bot", -> { Credentials.fetch(:DISCORD__BOT_TOKEN) }
      c.response :json
      c.response :raise_error
    end

    gd_response = conn.get("/api/v10/guilds/#{@guild_id}")

    @raw_gd_response = gd_response.body

    @event = Event.find_by(discord_guild_id: @guild_id)

    authorize @event, policy_class: DiscordPolicy
  end

  def unlink_server_action
    event = Event.find_by(discord_guild_id: params[:guild_id])
    authorize event, policy_class: DiscordPolicy

    cid = event.discord_channel_id

    event.update!(discord_guild_id: nil, discord_channel_id: nil)

    bot.send_message(cid, "The HCB organization #{event.name} has been unlinked from this Discord server, and notifications/announcements will no longer be sent here.")
    flash[:success] = "Successfully unlinked the organization #{event.name} from your Discord server"
    redirect_to root_path
  rescue => e
    Rails.error.report("Exception linking discord server: #{e}")
    flash[:error] = "We could not unlink your organization from your Discord server"
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

end
