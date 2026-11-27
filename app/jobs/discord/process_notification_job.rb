# frozen_string_literal: true

module Discord
  class ProcessNotificationJob < ApplicationJob
    include UsersHelper
    include Discord::Support

    queue_as :low
    sidekiq_options retry: false

    # A card charge's activity is created along with its raw Stripe transaction,
    # inside the import's transaction, but its ledger item only once that
    # transaction commits (CanonicalPendingTransaction#assign_ledger_item), so
    # this job can be picked up before the item its notification links to
    # exists. Wait for it a few times before sending the notification without
    # the link.
    LEDGER_ITEM_RETRY_WAIT = 10.seconds
    LEDGER_ITEM_RETRY_LIMIT = 6

    def perform(public_activity_id, attempt: 1)
      @activity = PublicActivity::Activity.find(public_activity_id)
      @event = @activity.event
      return if @event.discord_channel_id.blank?

      if awaiting_ledger_item? && attempt < LEDGER_ITEM_RETRY_LIMIT
        self.class.set(wait: LEDGER_ITEM_RETRY_WAIT).perform_later(public_activity_id, attempt: attempt + 1)
        return
      end

      @user = @activity.owner || User.system_user

      discord_scrubber = Loofah::Scrubber.new do |node|
        if node.name == "img"
          node.remove
        end
        # The activity's relative time (Discord shows the embed's own timestamp)
        node.remove if node.name == "time" && node.classes.include?("timestamp")
        node.remove if node.name == "svg"
        node.name = "p" if node.name == "li"
        node.remove if node.comment?
        node.set_attribute(:href, "https://hcb.hackclub.com#{node[:href]}") if node[:href].present?
      end

      begin
        key = @activity.key.gsub(".", "/")
        partial = "public_activity/#{key}_discord"
        text = ApplicationController.renderer.render(partial:, locals: { activity: @activity, p: { current_user: @user } })
        json = JSON.parse(text, symbolize_names: true)

        embed = {
          description: "No description",
          timestamp: @activity.created_at.iso8601,
          author: { name: @user.name, icon_url: profile_picture_for(@user) },
          color:
        }.merge(json[:embed] || {})

        components = format_components(json[:components])
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

    private

    def awaiting_ledger_item?
      @activity.key == "raw_pending_stripe_transaction.create" && @activity.trackable&.canonical_pending_transaction&.ledger_item.nil?
    end

  end

end
