# frozen_string_literal: true

module Discord
  class HandleInteractionJob < ApplicationJob
    queue_as :critical

    include Discord::Support

    def perform(interaction, responded: true)
      @responded = responded
      @interaction = interaction

      @user_id = @interaction.dig(:member, :user, :id) || @interaction.dig(:user, :id)
      @guild_id = @interaction.dig(:guild, :id)
      @channel_id = @interaction.dig(:channel, :id)
      @permissions = @interaction.dig(:member, :permissions)&.to_i

      @user = User.find_by(discord_id: @user_id) if @user_id
      @current_event = Event.find_by(discord_guild_id: @guild_id) if @guild_id

      return command_router if @interaction[:type] == 2
      return component_router if @interaction[:type] == 3
      return modal_router if @interaction[:type] == 5
    rescue => e
      if Rails.env.development?
        backtrace = e.backtrace.join("\n")
        if backtrace.length > 4_000
          backtrace = "#{backtrace[0..4_000]}..."
        end

        respond content: "**That didn't work!**\nYou're in development. Here's the backtrace:", embeds: [
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

    def command_router
      @command_name = @interaction.dig(:data, :name)

      unless ::Discord::RegisterCommandsJob.command(@command_name).present?
        respond content: "Unknown command: #{@command_name}" and return
      end

      send("#{@command_name.gsub("-", "_")}_command")
    end

    def component_router
      custom_id = @interaction.dig(:data, :custom_id)

      @interaction_name, @params = custom_id.split(":", 2)

      send("#{@interaction_name.gsub("-", "_")}_component")
    end

    def modal_router
      custom_id = @interaction.dig(:data, :custom_id)

      @interaction_name, @params = custom_id.split(":", 2)

      send("#{@interaction_name.gsub("-", "_")}_modal")
    end

    def generate_discord_link_url
      @generate_discord_link_url ||= url_helpers.discord_link_url(signed_discord_id: Discord.generate_signed(@user_id, purpose: :link_user))
    end

    def generate_discord_setup_url
      @generate_discord_setup_url ||= url_helpers.discord_setup_url(signed_guild_id: Discord.generate_signed(@guild_id, purpose: :link_server), signed_channel_id: Discord.generate_signed(@channel_id, purpose: :link_server))
    end

    def generate_discord_unlink_server_url
      @generate_discord_unlink_server_url ||= url_helpers.discord_unlink_server_url(signed_guild_id: Discord.generate_signed(@guild_id, purpose: :unlink_server))
    end

    def attach_receipt_component
      discord_message = Discord::Message.find_by(discord_message_id: @interaction.dig(:message, :id))
      activity = PublicActivity::Activity.find_by(id: discord_message&.activity_id)
      hcb_code = activity&.trackable&.canonical_pending_transaction&.local_hcb_code

      return respond(content: "Could not find the transaction to attach a receipt to.") unless activity&.key == "raw_pending_stripe_transaction.create"

      return respond(content: "This Discord server is not currently linked to the same HCB organization") unless activity.event_id == @current_event&.id && activity.event_id == hcb_code.event.id

      {
        "type": 9,
        "data": {
          "custom_id": "attach_receipt:#{hcb_code.hashid}",
          "title": "#{Money.from_cents(hcb_code.amount_cents.abs).format} for #{hcb_code.memo}",
          "components": [
            {
              "type": 18,
              "label": "Attach receipt",
              "component":
                {
                  "type": 19,
                  "custom_id": "receipt:#{hcb_code.hashid}",
                }
            },
          ]
        }
      }
    end

    def attach_receipt_modal
      hcb_code = HcbCode.find(@params)

      return respond(content: "This Discord server is not currently linked to the same HCB organization") unless hcb_code.event.id == @current_event&.id

      attachments = @interaction.dig(:data, :resolved, :attachments)
      file = attachments&.values&.first
      content_type = file[:content_type] if file.present?

      unless file.present? && (content_type == "application/pdf" || content_type&.start_with?("image/"))
        return respond(embeds: [{
                         title: "There was a problem with your receipt",
                         description: "Only images and PDF files are supported. Please try again.",
                         color:
                       }])
      end

      filename = file[:filename]
      io = URI(file[:url]).open

      ActiveRecord::Base.transaction do
        blob = ActiveStorage::Blob.create_and_upload!(
          io:,
          filename:,
          content_type:
        )

        ::ReceiptService::Create.new(attachments: [blob], uploader: @user, upload_method: :discord_bot_modal, receiptable: hcb_code).run!

        respond(embeds: [{
                  title: "Your receipt has been uploaded!",
                  description: "<@#{@user_id}>, your receipt for #{link_to("#{Money.from_cents(hcb_code.amount_cents.abs).format} at #{hcb_code.memo}", url_helpers.hcb_code_url(hcb_code))} has been uploaded successfully.",
                  color:
                }], components: button_to("View receipt", url_helpers.hcb_code_url(hcb_code)))
      end
    end

    def reimburse_component
      return require_linked_user unless @user

      report = @user.reimbursement_reports.create!(name: "Reimbursement report from Discord")

      respond content: "Your new reimbursement report has been created!", embeds: [
        {
          title: report.name,
          description: "Start by adding expenses",
          color:,
          url: url_helpers.reimbursement_report_url(report)
        }
      ], components: button_to("View on HCB", url_helpers.reimbursement_report_url(report)), flags: 1 << 6
    end

    def setup_component
      respond embeds: linking_embed, flags: 1 << 6
    end

    def ping_command
      respond content: "Pong! 🏓"
    end

    def link_command
      link_user_button = button_to("Link Discord account", generate_discord_link_url)
      link_server_button = button_to("Set up HCB on this server", generate_discord_setup_url)

      if @current_event.present? && @user.present?
        respond content: "HCB has already been setup for this Discord server!", embeds: linking_embed
      elsif !@current_event.present? && @user.present?
        respond content: "You've linked your Discord and HCB accounts, but this Discord server isn't connected to an HCB organization yet:",
                components: link_server_button,
                embeds: linking_embed
      elsif @current_event.present? && !@user.present?
        respond content: "This Discord server is connected to #{@current_event.name} on HCB. HCB is the platform your team uses to manage its finances. Finish your setup by linking your Discord account to HCB:",
                components: link_user_button,
                embeds: linking_embed
      else
        respond content: "Link your HCB account, and then connect this Discord server to an HCB organization:",
                components: [link_user_button, link_server_button],
                embeds: linking_embed
      end
    end

    def setup_command
      link_command # these do the same thing—it just makes it easier for users if they're two different commands
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

    TRANSACTION_LIMIT = 10

    def transactions_command
      return require_linked_event unless @current_event

      pending_transactions = PendingTransactionEngine::PendingTransaction::All.new(event_id: @current_event.id).run
      PendingTransactionEngine::PendingTransaction::AssociationPreloader.new(pending_transactions:, event: @current_event).run!

      remaining_limit = [TRANSACTION_LIMIT - pending_transactions.size, 0].max

      settled_transactions = TransactionGroupingEngine::Transaction::All.new(event_id: @current_event.id).run.first(remaining_limit)
      TransactionGroupingEngine::Transaction::AssociationPreloader.new(transactions: settled_transactions, event: @current_event).run!

      transactions = pending_transactions + settled_transactions

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
        name = "\"#{transaction.local_hcb_code.memo}\" for #{ApplicationController.helpers.render_money(transaction.amount_cents)}"
        name.prepend "[PENDING] " if transaction.is_a?(CanonicalPendingTransaction)
        {
          name:,
          value: "On #{transaction.date.strftime('%B %d, %Y')} - #{link_to("Details", url_helpers.hcb_code_url(transaction.local_hcb_code.hashid))}"
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

    REIMBURSEMENT_REPORT_LIMIT = 10
    def reimburse_command
      return require_linked_user unless @user

      reimbursement_reports = @user.reimbursement_reports.order(created_at: :desc).limit(REIMBURSEMENT_REPORT_LIMIT)

      report_fields = reimbursement_reports.map do |report|
        {
          name: "\"#{report.name}\" - #{report.status_text} (#{report.amount.format})",
          value: "Created on #{report.created_at.strftime('%B %d, %Y')} - #{link_to("Details", url_helpers.reimbursement_report_url(report))}"
        }
      end

      respond embeds: [
        {
          title: "Reimbursement reports for #{@user.preferred_name.presence || @user.first_name}",
          fields: report_fields,
          description: reimbursement_reports.empty? ? "No reimbursement reports yet" : nil,
          color:,
        }
      ], components: [
        button_to("Create new report", "reimburse:new", style: 3),
        button_to("View on HCB", url_helpers.my_reimbursements_url),
      ]
    end

    def missing_receipts_command
      return require_linked_user unless @user

      respond embeds: [
        {
          title: "You have #{@user.transactions_missing_receipt_count} transactions missing receipts",
          color:,
        }
      ], components: button_to("View on HCB", url_helpers.my_inbox_url)
    end

    def require_linked_user
      return respond content: "This command requires you to link this Discord account to HCB", components: button_to("Set up HCB", "setup") if @responded

      respond content: "This command requires you to link your Discord account to HCB", embeds: linking_embed, flags: 1 << 6
    end

    def linking_embed
      server_name = Discord::Bot.bot.server(@guild_id)&.name if @guild_id.present?
      user_name = Discord::Bot.bot.user(@user_id)&.username if @user_id.present?

      guild_setup_cta = can_manage_guild? ? link_to("Set up here", generate_discord_setup_url) : "Ask someone with **Manage server** permissions to run **`/setup`**" if @guild_id.present?

      [
        {
          title: "Set up HCB on Discord",
          color:,
          fields: [
            {
              name: "Discord Account (`@#{user_name}`) ↔ Your HCB Account",
              value: "Allows you to open reimbursement reports, view missing receipts, and take action on HCB.\n\n#{@user.present? ? "✅ Linked to #{@user.preferred_name.presence || @user.first_name} on HCB (#{link_to("disconnect", url_helpers.discord_unlink_user_url)})" : "❌ Not linked. #{link_to("Set up here", generate_discord_link_url)}"}\n",
            },
            (if @guild_id.present?
               {
                 name: "\nDiscord Server (#{server_name}) ↔ HCB Organization",
                 value: "Allows you to see your organization's balance, see transactions, and get notifications on Discord.\n\n#{@current_event.present? ? "✅ Connected to #{link_to(@current_event.name, url_helpers.event_url(@current_event.slug))} on HCB (#{link_to("disconnect", generate_discord_unlink_server_url)})" : "❌ Not connected. #{guild_setup_cta}"}"
               }
             end)
          ].compact
        }
      ]
    end

    def require_linked_event
      return respond content: "This command requires you to link this Discord server to HCB", components: button_to("Set up HCB", "setup") if @responded

      respond content: "This command requires you to link this Discord server to HCB", embeds: linking_embed, flags: 1 << 6
    end

    def respond(**body)
      body[:components] = format_components(body[:components]) if body[:components].present?

      unless @responded
        return { type: 4, data: body }
      end

      response = Discord::Bot.faraday_connection.patch("/api/v10/webhooks/#{Credentials.fetch(:DISCORD__APPLICATION_ID)}/#{@interaction[:token]}/messages/@original", body)

      response.body
    rescue Faraday::Error => e
      # Modify the original exception to append the response body to the message
      # so these are easier to debug
      puts(e.exception(<<~MSG))
        #{e.message}
        \tresponse_body: #{e.response_body.inspect}
      MSG
    end

    def can_manage_guild?
      @permissions & 0x0000000000000020 == 0x0000000000000020
    end

  end

end
