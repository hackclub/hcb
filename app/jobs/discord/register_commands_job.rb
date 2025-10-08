# frozen_string_literal: true

module Discord
  class RegisterCommandsJob < ApplicationJob
    queue_as :low

    def perform
      response = Discord::Bot.faraday_connection.put("/api/v10/applications/#{Credentials.fetch(:DISCORD__APPLICATION_ID)}/commands", ::Discord::RegisterCommandsJob.commands_for_discord)

      raw_response = response.body

      puts raw_response
    rescue Faraday::Error => e
      # Modify the original exception to append the response body to the message
      # so these are easier to debug
      raise(e.exception(<<~MSG))
        #{e.message}
        \tresponse_body: #{e.response_body.inspect}
      MSG
    end

    def self.commands
      [
        {
          name: "ping",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "Test the bot's responsiveness",
          options: [],
          meta: { ephemeral: false },
        },
        {
          name: "link",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "Link your Discord account to your HCB account",
          options: [],
          meta: { ephemeral: true },
        },
        {
          name: "setup",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "Connect your Discord server to your HCB organization",
          options: [],
          meta: { ephemeral: true },
        },
        {
          name: "balance",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "Check your organization's balance on HCB",
          options: [],
          meta: { ephemeral: false },
        },
        {
          name: "transactions",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "View your organization's recent transactions on HCB",
          options: [],
          meta: { ephemeral: false },
        },
        {
          name: "reimburse",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "Open a new reimbursement report on HCB",
          options: [],
          meta: { ephemeral: false },
        },
        {
          name: "missing-receipts",
          type: Discordrb::ApplicationCommand::TYPES[:chat_input],
          description: "List transactions missing receipts",
          options: [],
          meta: { ephemeral: false },
        }
      ]
    end

    def self.commands_for_discord
      commands.map { |command| command.except(:meta) }
    end

    def self.command(name)
      ::Discord::RegisterCommandsJob.commands.find { |command| command[:name] == name }
    end

  end

end
