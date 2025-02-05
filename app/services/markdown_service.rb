# frozen_string_literal: true

class MarkdownService
  include Singleton

  class MarkdownRenderer < Redcarpet::Render::HTML
    include ApplicationHelper # for render_money helper
    include UsersHelper # for mention users helper
    include Rails.application.routes.url_helpers

    def context(current_user: nil, record: nil, location: nil)
      @current_user = current_user
      @record = record
      @location = location
      self
    end

    def preprocess(fulldoc)

      # this is used to link expenses in expense report comments
      # code that finds any lines like #1 and replaces them with links to the elements with id

      fulldoc.gsub!(/#(\d+)/) do |match|
        id = $1.to_i
        "[#{match}](#{match})"
      end

      fulldoc
    end

    def postprocess(fulldoc)

      # this is used to strip "@" from user mentions post-HTML generation
      # this is because users type emails like: @sam.r.poder@gmail.com
      # to mention people, but RedCarpet's autolink only picks up
      # the email portion of that string.

      fulldoc.gsub!("@<span class=\"mention", "<span class=\"mention")
      fulldoc.gsub!("@<a class=\"mention", "<a class=\"mention")

      fulldoc
    end

    def link(link, title, alt_text)
      link_to alt_text, link, title:,
                              target: link.start_with?("#") ? "" : "_blank",
                              rel: link.start_with?("#") ? "" : "noopener noreferrer"
    end

    alias_method :format_link, :link

    def autolink(link, link_type)
      try_card_autolink(link) or
        try_hcb_autolink(link) or
        try_event_autolink(link) or
        try_user_autolink(link, link_type) or
        format_link(link, link_type, link)
    end

    def image(link, title, alt_text)
      image_tag link, title: title || alt_text,
                      alt: alt_text,
                      style: "width: 100%;"
    end

    private

    def try_event_autolink(link)
      found_event = link.match(/(#{app_hosts.join('|')})\/([\w|-]*)$/)

      if found_event
        event_id = found_event[2]
        event = Event.find_by_slug(event_id) || Event.find_by_id(event_id)

        return nil unless event

        Pundit.authorize(@current_user, event, :show?)

        link_to event.slug.to_s, link, target: "_blank", class: "autolink"
      end
    rescue Pundit::NotAuthorizedError
      return nil
    end

    def try_user_autolink(link, link_type)
      return nil unless link_type == :email

      u = User.find_by(email: link)
      return nil unless u && @record && Pundit.policy(u, @record)&.show?

      if @location == :email
        return mail_to link, "@#{u.name}", class: "mention"
      end

      user_mention(u, click_to_mention: true, comment_mention: true)
    end

    def try_card_autolink(link)
      found_card = link.match(/(#{app_hosts.join('|')})\/stripe_cards\/(\d*)/)

      if found_card
        card_id = found_card[2]
        card = StripeCard.find_by_id card_id
        event = card&.event
        return nil unless card && event

        Pundit.authorize(@current_user, card, :show?)

        link_to "#{card.status_text.downcase} card (#{card.user.first_name})",
                link,
                target: "_blank",
                class: "tooltipped tooltipped--e autolink",
                "aria-label" => card.status_text.to_s
      end
    rescue Pundit::NotAuthorizedError
      return nil
    end

    def try_hcb_autolink(link)
      found_link = link.match(/(#{app_hosts.join('|')})\/hcb\/(\w+)\#comment-(\w+)/)
      found_link ||= link.match(/(#{app_hosts.join('|')})\/hcb\/(\w+)/)

      if found_link
        hcb_code = found_link[2]
        comment = found_link[3]
        hcb = HcbCode.find_by_hashid hcb_code
        return nil unless hcb

        Pundit.authorize(@current_user, hcb, :show?)
        link_to "#{'comment on ' if comment.present?}#{hcb.humanized_type.downcase} (HCB-#{hcb.hashid})",
                link,
                target: "_blank",
                class: "tooltipped tooltipped--e autolink",
                "aria-label" => "#{render_money hcb.amount_cents} - #{hcb.memo}"
      else
        return nil
      end
    rescue Pundit::NotAuthorizedError
      return nil
    end

    def app_hosts
      hosts = []
      hosts << Rails.application.credentials.default_url_host[:live]
      hosts << Rails.application.credentials.default_url_host[:test] if Rails.env.development?

      hosts.map { |h| Regexp.escape h }
    end

  end

  def renderer(current_user: nil, record: nil, location: nil)
    markdown_renderer = MarkdownRenderer.new(hard_wrap: true, filter_html: true)
                                        .context(current_user:, record:, location:)
    Redcarpet::Markdown.new(markdown_renderer, strikethrough: true,
                                               tables: true,
                                               autolink: true)
  end

end
