# frozen_string_literal: true

module Discord
  class ProcessNotificationJob < ApplicationJob
    queue_as :low

    def perform(public_activity_id)
      @activity = PublicActivity::Activity.find(public_activity_id)
      @event = @activity.event

      user_avatar_url = nil
      timestamp = nil
      user_name = nil

      discord_scrubber = Loofah::Scrubber.new do |node|
        if node.name == "span" && node[:class].present? && node[:class].include?("muted")
          user_name ||= node.text.strip
        end
        if node.name == "img"
          user_avatar_url = node[:src]
          node.remove
        end
        if node["data-timestamp-time-value".to_sym].present?
          timestamp = node["data-timestamp-time-value".to_sym]
          node.remove
        end
        node.remove if node.name == "svg"
        node.name = "p" if node.name == "li"
        node.remove if node.comment?
        node.set_attribute(:href, "https://hcb.hackclub.com#{node[:href]}") if node[:href].present?
      end

      html = ApplicationController.renderer.render(partial: "public_activity/activity", locals: { activity: @activity, current_user: User.system_user })
      html = Loofah.scrub_html5_fragment(html, discord_scrubber)

      text = ReverseMarkdown.convert(html)[0..4000]

      bot.send_message(@event.discord_channel_id, nil, false, { description: text, timestamp: Time.at((timestamp.to_i / 1000).to_i).iso8601, author: { name: user_name, icon_url: user_avatar_url }, color: })
    end

    private

    def bot
      @bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)
    end

    def color
      if Rails.env.development?
        0x33d6a6
      else
        0xec3750
      end
    end

  end

end
