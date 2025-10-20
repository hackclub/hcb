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

      channel = Discord::Bot.bot.pm_channel(user_id)
      Discord::Bot.bot.send_message(channel, "Welcome to HCB! Link your Discord account to your HCB account by going to #{discord_link_url(discord_id: user_id)}")
    end

    head :no_content
  end

  def interaction_webhook
    case params[:type]
    when 1 # PING
      return render json: { type: 1 } # PONG
    when 2 # application command
      ephemeral = ::Discord::RegisterCommandsJob.command(params.dig(:data, :name))&.dig(:meta, :ephemeral) || false
      render json: { type: 5, data: { flags: ephemeral ? 1 << 6 : 0 } } # Acknowledge interaction & will edit response later
      ::Discord::HandleInteractionJob.perform_later(params.to_unsafe_h, responded: true)
    when 3, 5 # message component, modal submit
      render json: ::Discord::HandleInteractionJob.perform_now(params.to_unsafe_h, responded: false)
    else
      Rails.error.unexpected "🚨 Unknown payload received from Discord on interaction webhook: #{params.inspect}"
    end
  end

  def link
    authorize nil, policy_class: DiscordPolicy
    @signed_discord_id = params[:signed_discord_id]
    redirect_to_discord_bot_install_link and return if @signed_discord_id.nil?

    @discord_id = Discord.verify_signed(@signed_discord_id, purpose: :link_user)
    @discord_user = Discord::Bot.bot.user(@discord_id)

    redirect_to_discord_bot_install_link if @discord_user.nil?
  end

  def create_link
    discord_id = Discord.verify_signed(params[:signed_discord_id], purpose: :link_user)
    authorize nil, policy_class: DiscordPolicy

    redirect_to_discord_bot_install_link unless Discord::Bot.bot.user(discord_id).present?

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

    @guild = Discord::Bot.bot.server(@guild_id)
    @channel = Discord::Bot.bot.channel(@channel_id)

    redirect_to_discord_bot_install_link if @guild.nil? || @channel.nil?
  end

  def create_server_link
    event = Event.find(params[:event_id])
    authorize event, policy_class: DiscordPolicy

    @guild_id = Discord.verify_signed(params[:signed_guild_id], purpose: :link_server)
    @channel_id = Discord.verify_signed(params[:signed_channel_id], purpose: :link_server)

    @guild = Discord::Bot.bot.server(@guild_id)
    @channel = Discord::Bot.bot.channel(@channel_id)

    return redirect_to_discord_bot_install_link if @guild.nil? || @channel.nil?

    if @guild.id != @channel.server.id
      raise StandardError.new "channel #{@channel.id} says it's in guild #{@channel.guild_id}, but we have guild #{@guild.id}!"
    end

    if event.update(discord_guild_id: @guild_id, discord_channel_id: @channel_id)
      Discord::Bot.bot.send_message(@channel_id, "The HCB organization #{event.name} has been successfully linked to this Discord server by #{current_user.name}! Notifications and announcements will be sent in this channel, <\##{@channel_id}>.")
      flash[:success] = "Successfully linked the organization #{event.name} to your Discord server"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.unexpected("Exception linking discord server: #{e.message}")
    flash[:error] = "We could not link the selected organization to your Discord server"
  ensure
    if event.present?
      redirect_to edit_event_path(event)
    else
      redirect_to root_path
    end
  end

  def unlink_user
    @user = Discord::Bot.bot.user(current_user.discord_id)

    authorize nil, policy_class: DiscordPolicy
  end

  def unlink_user_action
    authorize nil, policy_class: DiscordPolicy

    if current_user.update(discord_id: nil)
      flash[:success] = "Successfully unlinked your Discord user"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.unexpected("Exception unlinking discord user: #{e.message}")
    flash[:error] = "We could not unlink your Discord user"
  ensure
    redirect_to root_path
  end

  def unlink_server
    @signed_guild_id = params[:signed_guild_id]
    @guild_id = Discord.verify_signed(@signed_guild_id, purpose: :unlink_server)

    @guild = Discord::Bot.bot.server(@guild_id)
    @event = Event.find_by(discord_guild_id: @guild_id)

    authorize @event, policy_class: DiscordPolicy
  end

  def unlink_server_action
    @guild_id = Discord.verify_signed(params[:signed_guild_id], purpose: :unlink_server)

    event = Event.find_by!(discord_guild_id: @guild_id)
    authorize event, policy_class: DiscordPolicy

    cid = event.discord_channel_id

    if event.update(discord_guild_id: nil, discord_channel_id: nil)
      Discord::Bot.bot.send_message(cid, "The HCB organization #{event.name} has been unlinked from this Discord server by #{current_user.name}, and notifications/announcements will no longer be sent here.")
      flash[:success] = "Successfully unlinked the organization #{event.name} from your Discord server"
    else
      flash[:error] = event.errors.full_messages.to_sentence
    end
  rescue => e
    Rails.error.unexpected("Exception unlinking discord server: #{e.message}")
    flash[:error] = "We could not unlink your organization from your Discord server"
  ensure
    if event.present?
      redirect_to edit_event_path(event)
    else
      redirect_to root_path
    end
  end

  private

  def verify_discord_signature
    head :unauthorized unless Discord::Bot.verify_webhook_signature(request)
  end

  def redirect_to_discord_bot_install_link
    redirect_to Discord::Bot.install_link, allow_other_host: true
  end

end
