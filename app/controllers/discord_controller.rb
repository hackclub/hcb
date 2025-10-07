# frozen_string_literal: true

class DiscordController < ApplicationController
  protect_from_forgery except: [:event_webhook, :interaction_webhook]
  skip_before_action :signed_in_user, only: [:event_webhook, :interaction_webhook]
  before_action :verify_discord_signature, only: [:event_webhook, :interaction_webhook]
  skip_after_action :verify_authorized, only: [:event_webhook, :interaction_webhook]

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
      render json: { type: 1 } # PONG

    elsif params[:type] == 2 # application command
      render json: { type: 5 } # Acknowledge interaction & will edit response later
      ::Discord::HandleInteractionJob.perform_later(params.to_unsafe_h)

    else
      Rails.error.unexpected "🚨 Unknown payload received from Discord on interaction webhook: #{params.inspect}"
    end
  end

  def link
    @signed_message = params[:signed_message]
    authorize nil, policy_class: DiscordPolicy

    h, time = Rails.application.message_verifier(:link_discord_account).verify(@signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

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
    signed_message = params[:signed_message]

    h, time = Rails.application.message_verifier(:link_discord_account).verify(signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

    if current_user.update(discord_id: h[:discord_id])
      flash[:success] = "Successfully linked Discord account"
    else
      flash[:error] = current_user.errors.full_messages.to_sentence
    end
    redirect_to edit_user_path(current_user)

  end

  def setup
    @signed_message = params[:signed_message]
    authorize nil, policy_class: DiscordPolicy

    h, time = Rails.application.message_verifier(:link_server).verify(signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

    @guild_id = h[:guild_id]
    @channel_id = h[:channel_id]

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
    signed_message = params[:signed_message]
    event = Event.find(params[:event_id])

    authorize event, policy_class: DiscordPolicy

    h, time = Rails.application.message_verifier(:link_server).verify(signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

    if event.update(discord_guild_id: h[:guild_id], discord_channel_id: h[:channel_id])
      bot.send_message(h[:channel_id], "The HCB organization #{event.name} has been successfully linked to this Discord server! Notifications and announcements will be sent in this channel, <\##{h[:channel_id]}>.")
      flash[:success] = "Successfully linked the organization #{event.name} to your Discord server"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.report("Exception linking discord server: #{e}")
    flash[:error] = "We could not link the selected organization to your Discord server"
  ensure
    redirect_to edit_event_path(event)
  end

  def unlink_server
    @signed_message = params[:signed_message]

    h, time = Rails.application.message_verifier(:unlink_server).verify(@signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

    @guild_id = h[:guild_id]

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
    signed_message = params[:signed_message]

    h, time = Rails.application.message_verifier(:unlink_server).verify(signed_message)

    if !time.future || !h
      flash[:error] = "The link you used appears to be invalid. Please restart the linking process."
      return redirect_to root_path
    end

    event = Event.find_by(discord_guild_id: h[:guild_id])
    authorize event, policy_class: DiscordPolicy

    cid = event.discord_channel_id

    if event.update(discord_guild_id: nil, discord_channel_id: nil)
      bot.send_message(cid, "The HCB organization #{event.name} has been unlinked from this Discord server, and notifications/announcements will no longer be sent here.")
      flash[:success] = "Successfully unlinked the organization #{event.name} from your Discord server"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.report("Exception linking discord server: #{e}")
    flash[:error] = "We could not unlink your organization from your Discord server"
  ensure
    redirect_to edit_event_path(event)
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
