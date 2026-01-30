# frozen_string_literal: true

module Discord
  class ProcessNotificationJob < ApplicationJob
    include UsersHelper
    include Discord::Support

    queue_as :low
    sidekiq_options retry: false

    def perform(public_activity_id)
      @activity = PublicActivity::Activity.find(public_activity_id)
      @event = @activity.event
      return if @event.discord_channel_id.blank?

      @user = @activity.owner || User.system_user

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

      begin
        key = @activity.key.gsub(".", "/")
        partial = "public_activity/#{key}_discord"
        text = ApplicationController.renderer.render(partial:, locals: { activity: @activity, p: { current_user: @user } })
        json = JSON.parse(text)

        embed = {
          description: "No description",
          timestamp: @activity.created_at.iso8601,
          author: { name: @user.name, icon_url: profile_picture_for(@user) },
          color:
        }.merge(json["embed"] || {})

        components = format_components(json["components"])
      rescue ActionView::MissingTemplate, ActionView::Template::Error # fallback to HTML (which already exists for all activities)
        @user = User.system_user # this templates may use "you" if current user == owner which doesn't make sense in a team context
        html = ApplicationController.renderer.render(partial: "public_activity/activity", locals: { activity: @activity, current_user: @user })
        html = Loofah.scrub_html5_fragment(html, discord_scrubber)

        text = ReverseMarkdown.convert(html)[0..4000]

        embed = {
          description: text,
          timestamp: @activity.created_at.iso8601,
          author: { name: @user.name, icon_url: profile_picture_for(@user) },
          color:
        }

        components = []
      end

      sent_message = Discord::Bot.bot.send_message(@event.discord_channel_id, nil, false, embed, nil, nil, nil, components)

      Discord::Message.create!(
        discord_channel_id: @event.discord_channel_id,
        discord_guild_id: @event.discord_guild_id,
        discord_message_id: sent_message.id,
        activity: @activity
      )
    end

  end

end
