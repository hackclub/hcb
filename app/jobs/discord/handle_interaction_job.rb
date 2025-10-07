# frozen_string_literal: true

module Discord
  class HandleInteractionJob < ApplicationJob
    queue_as :high

    def perform(interaction)
      @interaction = interaction

      @user_id = @interaction.dig(:member, :user, :id) || @interaction.dig(:user, :id)
      @guild_id = @interaction.dig(:guild, :id)
      @channel_id = @interaction.dig(:channel, :id)
      @permissions = @interaction.dig(:member, :permissions)&.to_i

      @current_user = User.find_by(discord_id: @user_id) if @user_id
      @current_event = Event.find_by(discord_guild_id: @guild_id) if @guild_id

      command_name = @interaction.dig(:data, :name)

      unless command_name.in?(::Discord::RegisterCommandsJob.commands.pluck(:name))
        respond content: "Unknown command: #{command_name}" and return
      end

      return send("#{command_name.gsub("-", "_")}_command")
    rescue => e
      if Rails.env.development?
        backtrace = e.backtrace.join("\n")
        if backtrace.length > 4_000
          backtrace = "#{backtrace[0..4_000]}..."
        end

        respond content: "**That didn't work!**\nWe're going to debug what went wrong.", embeds: [
          {
            title: e.message,
            description: "```\n#{backtrace}\n```",
            color: 0xCC0100,
          }
        ]
      else
        respond content: "**That didn't work!**\nWe're going to debug what went wrong."
      end

      Rails.error.report(e)
    end

    private

    def ping_command
      respond content: "Pong!"
    end

    def link_command
      if @current_event.present? && @current_user.present?
        respond content: "HCB has already been setup for this Discord server!", embeds: linking_embed
      elsif !@current_event.present? && @current_user.present?
        respond content: "You've linked your Discord and HCB accounts, but this Discord server isn't connected to an HCB organization yet:", components: button_to("Set up HCB on this server", url_helpers.discord_setup_url(guild_id: @guild_id, channel_id: @channel_id)), embeds: linking_embed
      elsif @current_event.present? && !@current_user.present?
        respond content: "HCB has already been setup for this Discord server, but your Discord account isn't linked to your HCB account yet:", components: button_to("Link Discord account", url_helpers.discord_link_url(discord_id: @user_id)), embeds: linking_embed
      else
        respond content: "Link your HCB account, and then connect this Discord server to an HCB organization:", components: [button_to("Link Discord account", url_helpers.discord_link_url(discord_id: @user_id)), button_to("Set up HCB on this server", url_helpers.discord_setup_url(guild_id: @guild_id, channel_id: @channel_id))], embeds: linking_embed
      end
    end

    def setup_command
      link_command
    end

    def balance_command
      return require_linked_event unless @current_event

      respond embeds: [
        {
          title: "#{@current_event.name}'s balance is #{ApplicationController.helpers.render_money @current_event.balance_available_v2_cents}",
          color:
        }
      ], components: button_to("View on HCB", url_helpers.my_inbox_url)
    end

    def transactions_command
      return require_linked_event unless @current_event

      transactions = @current_event.canonical_pending_transactions.order(created_at: :desc).limit(4)

      if transactions.length == 0
        respond embeds: [
          {
            title: "Recent transactions for #{@current_event.name}",
            description: "No transactions yet...",
            color:,
          }
        ]
        return
      end

      transaction_fields = transactions.map do |transaction|
        {
          name: "\"#{transaction.smart_memo}\" for #{ApplicationController.helpers.render_money(transaction.amount_cents)}",
          value: "On #{transaction.created_at.strftime('%B %d, %Y')} - #{link_to("Details", url_helpers.hcb_code_url(transaction.local_hcb_code.hashid))}"
        }
      end

      respond embeds: [
        {
          title: "Recent transactions for #{@current_event.name}",
          fields: transaction_fields,
          color:,
        }
      ], components: button_to("Go to HCB", url_helpers.event_url(@current_event.slug))
    end

    def reimburse_command
      respond content: "Debugger", embeds: [
        {
          title: "Debugger",
          description: "```\n#{JSON.pretty_generate(@interaction)[0..4085]}\n```",
          color: 0xCC0100,
        }
      ]
    end

    def missing_receipts_command
      return require_linked_user unless @current_user

      respond embeds: [
        {
          title: "You have #{@current_user.transactions_missing_receipt_count} transactions missing receipts",
          color:,
        }
      ], components: button_to("View on HCB", url_helpers.my_inbox_url)
    end

    def require_linked_user
      respond content: "This command requires you to link your Discord account to HCB", embeds: linking_embed
    end

    def linking_embed
      server_name = bot.server(@guild_id)&.name if @guild_id.present?
      user_name = bot.user(@user_id)&.username if @user_id.present?

      guild_setup_cta = can_manage_guild? ? link_to("Set up here", url_helpers.discord_setup_url(guild_id: @guild_id, channel_id: @channel_id)) : "Ask someone with **Manage server** permissions to run **`/setup`**" if @guild_id.present?

      [
        {
          title: "Set up HCB on Discord",
          color:,
          fields: [
            {
              name: "Discord Account (`@#{user_name}`) ↔ Your HCB Account",
              value: "Allows you to open reimbursement reports, view missing receipts, and take action on HCB.\n\n#{@current_user.present? ? "✅ Linked to #{@current_user.preferred_name.presence || @current_user.first_name} on HCB" : "❌ Not linked. #{link_to("Set up here", url_helpers.discord_link_url(discord_id: @user_id))}"}\n",
            },
            (if @guild_id.present?
               {
                 name: "\nDiscord Server (#{server_name}) ↔ HCB Organization",
                 value: "Allows you to see your organization's balance, see transactions, and get notifications on Discord.\n\n#{@current_event.present? ? "✅ Connected to #{link_to(@current_event.name, url_helpers.event_url(@current_event.slug))} on HCB (#{link_to("disconnect", url_helpers.discord_unlink_server_url(guild_id: @guild_id))})" : "❌ Not connected. #{guild_setup_cta}"}"
               }
             end)
          ].compact
        }
      ]
    end

    def require_linked_event
      respond content: "This command requires you to link this Discord server to HCB", embeds: linking_embed
    end

    def button_to(label, url)
      {
        type: 1,
        components: [
          {
            type: 2,
            url:,
            label:,
            style: 5,
            emoji: { id: "1424492375295791185" }
          }
        ]
      }
    end

    def link_to(label, url)
      "[#{label}](#{url})"
    end

    def respond(**body)
      puts "HIJ>response method called"

      if body[:components].present? && !body[:components].is_a?(Array)
        body[:components] = [body[:components]]
      end

      conn = Faraday.new url: "https://discord.com" do |c|
        c.request :json
        c.request :authorization, "Bot", -> { Credentials.fetch(:DISCORD__BOT_TOKEN) }
        c.response :json
        c.response :raise_error
      end

      response = conn.patch("/api/v10/webhooks/#{Credentials.fetch(:DISCORD__APPLICATION_ID)}/#{@interaction[:token]}/messages/@original", body)

      response.body
    rescue Faraday::Error => e
      # Modify the original exception to append the response body to the message
      # so these are easier to debug
      puts(e.exception(<<~MSG))
        #{e.message}
        \tresponse_body: #{e.response_body.inspect}
      MSG
    end

    def color
      if Rails.env.development?
        0x33d6a6
      else
        0xec3750
      end
    end

    def bot
      @bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)
    end

    def can_manage_guild?
      @permissions & 0x0000000000000020 == 0x0000000000000020
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end

  end

end
