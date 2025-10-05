# frozen_string_literal: true

module Discord
  class RegisterCommandsJob < ApplicationJob
    queue_as :low

    def perform
      conn = Faraday.new url: "https://discord.com" do |c|
        c.request :json
        c.request :authorization, "Bot", -> { Credentials.fetch(:DISCORD__BOT_TOKEN) }
        c.response :json
        c.response :raise_error
      end

      response = conn.put("/api/v10/applications/#{Credentials.fetch(:DISCORD__APPLICATION_ID)}/commands", ::Discord::RegisterCommandsJob.commands)

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
          type: 1,
          description: "Test the bot's responsiveness",
          options: [],
        },
        {
          name: "link",
          type: 1,
          description: "Link your Discord account to your HCB account",
          options: [],
        },
        {
          name: "setup",
          type: 1,
          description: "Connect your Discord server to your HCB organization",
          options: [],
        },
        {
          name: "balance",
          type: 1,
          description: "Check your organization's balance on HCB",
          options: [],
        },
        {
          name: "transactions",
          type: 1,
          description: "View your organization's recent transactions on HCB",
          options: [],
        },
        {
          name: "reimburse",
          type: 1,
          description: "Open a new reimbursement report on HCB",
          options: [],
        },
        {
          name: "missing-receipts",
          type: 1,
          description: "List transactions missing receipts",
          options: [],
        }
      ]
    end

  end

end
