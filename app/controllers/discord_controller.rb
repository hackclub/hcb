# frozen_string_literal: true

class DiscordController < ApplicationController
  protect_from_forgery except: [:event_webhook, :interaction_webhook]
  skip_before_action :signed_in_user, only: [:event_webhook, :interaction_webhook]
  before_action :verify_discord_signature, only: [:event_webhook, :interaction_webhook]
  skip_after_action :verify_authorized, only: [:event_webhook, :interaction_webhook]

  rescue_from ActiveSupport::MessageVerifier::InvalidSignature do |e|
    Rails.error.report(e)
    flash[:error] = "The link you used has expired or appears to be invalid. Please try re-running the command in Discord."
    redirect_back_or_to root_path
  end

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
    if params[:type] == 1 # PING
      render json: { type: 1 } # PONG

    elsif params[:type] == 2 # application command
      ephemeral = ::Discord::RegisterCommandsJob.command(params.dig(:data, :name))&.dig(:meta, :ephemeral) || false
      render json: { type: 5, data: { flags: ephemeral ? 1 << 6 : 0 } } # Acknowledge interaction & will edit response later
      ::Discord::HandleInteractionJob.perform_later(params.to_unsafe_h)

    else
      Rails.error.unexpected "🚨 Unknown payload received from Discord on interaction webhook: #{params.inspect}"
    end
  end

  def link
    authorize nil, policy_class: DiscordPolicy
    @signed_discord_id = params[:signed_discord_id]
    redirect_to_discord_bot_install_link and return if @signed_discord_id.nil?

    @discord_id = Discord.verify_signed(@signed_discord_id, purpose: :link_user)
    @discord_user = bot.user(@discord_id)

    redirect_to_discord_bot_install_link if @discord_user.nil?
  end

  def create_link
    discord_id = Discord.verify_signed(params[:signed_discord_id], purpose: :link_user)
    authorize nil, policy_class: DiscordPolicy

    if current_user.update(discord_id:)
      flash[:success] = "Successfully linked Discord account"
    else
      flash[:error] = current_user.errors.full_messages.to_sentence
    end
    redirect_to edit_user_path(current_user)

  end

  def setup
    authorize nil, policy_class: DiscordPolicy

    @signed_guild_id = params[:signed_guild_id]
    @signed_channel_id = params[:signed_channel_id]
    redirect_to_discord_bot_install_link and return if @signed_guild_id.nil? || @signed_channel_id.nil?

    @guild_id = Discord.verify_signed(@signed_guild_id, purpose: :link_server)
    @channel_id = Discord.verify_signed(@signed_channel_id, purpose: :link_server)

    @guild = bot.server(@guild_id)
    @channel = bot.channel(@channel_id)

    redirect_to_discord_bot_install_link if @guild.nil? || @channel.nil?
  end

  def create_server_link
    event = Event.find(params[:event_id])
    authorize event, policy_class: DiscordPolicy

    @guild_id = Discord.verify_signed(params[:signed_guild_id], purpose: :link_server)
    @channel_id = Discord.verify_signed(params[:signed_channel_id], purpose: :link_server)

    if event.update(discord_guild_id: @guild_id, discord_channel_id: @channel_id)
      bot.send_message(@channel_id, "The HCB organization #{event.name} has been successfully linked to this Discord server by #{current_user.name}! Notifications and announcements will be sent in this channel, <\##{@channel_id}>.")
      flash[:success] = "Successfully linked the organization #{event.name} to your Discord server"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.report("Exception linking discord server: #{e}")
    flash[:error] = "We could not link the selected organization to your Discord server"
  ensure
    redirect_to edit_event_path(event) if event.present?
  end

  def unlink_server
    @signed_guild_id = params[:signed_guild_id]
    @guild_id = Discord.verify_signed(@signed_guild_id, purpose: :unlink_server)

    @guild = bot.server(@guild_id)
    @event = Event.find_by(discord_guild_id: @guild_id)

    authorize @event, policy_class: DiscordPolicy
  end


  def unlink_server_action
    @guild_id = Discord.verify_signed(params[:signed_guild_id], purpose: :unlink_server)

    event = Event.find_by(discord_guild_id: @guild_id)
    authorize event, policy_class: DiscordPolicy

    cid = event.discord_channel_id

    if event.update(discord_guild_id: nil, discord_channel_id: nil)
      bot.send_message(cid, "The HCB organization #{event.name} has been unlinked from this Discord server by #{current_user.name}, and notifications/announcements will no longer be sent here.")
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

  def redirect_to_discord_bot_install_link
    install_link = "https://discord.com/oauth2/authorize?client_id=#{Credentials.fetch(:DISCORD__APPLICATION_ID)}"
    redirect_to install_link, allow_other_host: true
  end

end
