# frozen_string_literal: true

module Discord
  class HandleInteractionJob < ApplicationJob
    queue_as :high

    def perform(interaction)
      @interaction = interaction
      @user_id = interaction.dig(:member, :user, :id) || interaction.dig(:user, :id)

      command_name = interaction[:data][:name]

      unless command_name.in?(::Discord::RegisterCommandsJob.commands.pluck(:name))
        respond content: "Unknown command: #{command_name}" and return
      end

      return send("#{command_name}_command")
    rescue => e
      if Rails.env.development?
        backtrace = e.backtrace.join("\n")
        if backtrace.length > 4_000
          backtrace = backtrace[0..4_000] + "..."
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
      respond content: "Go here: #{Rails.application.routes.url_helpers.discord_link_url(discord_id: @user_id)}"
    end

    def balance_command
      respond content: "Your balance: $67,000"
    end

    def transactions_command

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

    def respond(**body)
      puts "HIJ>response method called"

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

  end

end
