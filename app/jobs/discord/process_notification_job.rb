# frozen_string_literal: true

module Discord
  class ProcessNotificationJob < ApplicationJob
    include UsersHelper

    queue_as :low

    def perform(public_activity_id)
      @activity = PublicActivity::Activity.find(public_activity_id)
      @event = @activity.event
      @user = @activity.owner

      discord_scrubber = Loofah::Scrubber.new do |node|
        if node.name == "img"
          node.remove
        end
        if node["data-timestamp-time-value".to_sym].present?
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

      Discord::Bot.bot.send_message(@event.discord_channel_id, nil, false, {
                                      description: text,
                                      timestamp: @activity.created_at.iso8601,
                                      author: { name: @user.name, icon_url: profile_picture_for(@activity.owner) },
                                      color:
                                    })
    end

    private

    def color
      if Rails.env.development?
        0x33d6a6
      else
        0xec3750
      end
    end

  end

end
