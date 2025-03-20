# frozen_string_literal: true

require "digest/md5"
require "cgi"

module UsersHelper
  def gravatar_url(email, name, id, size)
    name ||= begin
      temp = email.split("@").first.split(/[^a-z\d]/i).compact_blank
      temp.length == 1 ? temp.first.first(2) : temp.first(2).map(&:first).join
    end
    hex = Digest::MD5.hexdigest(email.downcase.strip)
    "https://gravatar.com/avatar/#{hex}?s=#{size}&d=https%3A%2F%2Fui-avatars.com%2Fapi%2F/#{CGI.escape(name)}/#{size}/#{get_user_color(id)}/fff"
  end

  def profile_picture_for(user, size = 24, default_image: nil)
    default_image ||= "https://cloud-80pd8aqua-hack-club-bot.vercel.app/0image-23.png"

    # profile_picture_for works with OpenStructs (used on the front end when a user isn't registered),
    # so this method shows Gravatars/intials for non-registered and allows showing of uploaded profile pictures for registered users.
    if user.nil?
      default_image
    elsif Rails.env.production? && (user.is_a?(User) && user&.profile_picture&.attached?)
      Rails.application.routes.url_helpers.url_for(user.profile_picture.variant(
                                                     thumbnail: "#{size * 2}x#{size * 2}^",
                                                     gravity: "center",
                                                     extent: "#{size * 2}x#{size * 2}"
                                                   ))
    else
      gravatar_url(user.email, user.initials, user.id, size * 2)
    end
  end

  def current_user_flavor_text
    [
      "You!",
      "Yourself!",
      "It's you!",
      "Someone you used to know!",
      "You probably know them!",
      "You’re currently looking in a mirror",
      "it u!",
      "Long time no see!",
      "You look great!",
      "Your best friend",
      "Hey there, big spender!",
      "Yes, you!",
      "Who do you think you are?!",
      "Who? You!",
      "You who!",
      "Yahoo!",
      "dats me!",
      "dats u!",
      "byte me!",
      "despite everything, it's still you!",
      "the person reading this :-)",
      "our favorite user currently reading this text!"
    ]
  end

  def avatar_for(user, size = 24, options = {}, click_to_mention: false, default_image: nil)
    src = profile_picture_for(user, size, default_image:)
    current_user = defined?(current_user) ? current_user : nil

    klasses = ["rounded-full", "shrink-none"]
    klasses << "avatar--current-user" if user && user == current_user
    klasses << options[:class] if options[:class]
    klass = klasses.join(" ")

    alt = current_user_flavor_text.sample if user == current_user
    alt ||= user&.initials
    alt ||= "Brown dog grinning and gazing off into the distance"

    options[:data] = (options[:data] || {}).merge(behavior: "mention", mention_value: "@#{user.email}") if click_to_mention && user

    image_tag(src, options.merge(loading: "lazy", alt:, width: size, height: size, class: klass))
  end

  def user_mention(user, options = {}, default_name = "No User", click_to_mention: false, comment_mention: false, default_image: nil)
    name = content_tag :span, (user&.initial_name || default_name)
    current_user = defined?(current_user) ? current_user : nil
    avi = avatar_for(user, 24, options[:avatar] || {}, click_to_mention:, default_image:)

    klasses = ["mention"]
    klasses << %w[mention--admin tooltipped tooltipped--n] if user&.auditor? && !options[:disable_tooltip]
    klasses << %w[mention--current-user tooltipped tooltipped--n] if current_user && (user&.id == current_user.id) && !options[:disable_tooltip]
    klasses << %w[badge bg-muted ml0] if comment_mention
    klasses << options[:class] if options[:class]
    klass = klasses.uniq.join(" ")

    aria_label = if options[:aria_label]
                   options[:aria_label]
                 elsif user.nil?
                   "No user found"
                 elsif user.id == current_user&.id
                   current_user_flavor_text.sample
                 elsif user.auditor?
                  "#{user.name} is an auditor"
                 elsif user.admin?
                   "#{user.name} is an admin"
                 end

    content = if user&.auditor? && !options[:hide_avatar]
                bolt = inline_icon "admin-badge", size: 20
                avi + bolt + name
              elsif options[:hide_avatar]
                name
              else
                avi + name
              end

    content_tag :span, content, class: klass, 'aria-label': aria_label
  end

  def admin_tool(class_name = "", element = "div", override_pretend: false, **options, &block)
    return unless current_user&.auditor? || (override_pretend && current_user&.admin_override_pretend?)

    concat content_tag(element, class: "admin-tools #{class_name}", **options, &block)
  end

  def admin_tool_if(condition, *args, **options, &block)
    # If condition is false, it displays the content for ALL users. Otherwise,
    # it's only visible to admins.
    yield and return unless condition

    admin_tool(*args, **options, &block)
  end

  def creator_bar(object, options = {})
    creator = if defined?(object.creator)
                object.creator
              elsif defined?(object.sender)
                object.sender
              else
                object.user
              end
    mention = user_mention(creator, options, default_name = "Anonymous User")
    content_tag :div, class: "comment__name" do
      mention + relative_timestamp(object.created_at, prefix: options[:prefix], class: "h5 muted")
    end
  end

  def user_birthday?(user = current_user)
    user&.birthday?
  end

  def onboarding_gallery
    [
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/0image.png",
        url: "https://hcb.hackclub.com/zephyr",
        overlay_color: "#802434",
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/1image.png",
        url: "https://hcb.hackclub.com/the-charlotte-bridge",
        overlay_color: "#805b24",
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/2image.png",
        url: "https://hcb.hackclub.com/windyhacks",
        overlay_color: "#807f0a",
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/3image.png",
        url: "https://hcb.hackclub.com/the-innovation-circuit",
        overlay_color: "#22806c",
        object_position: "center"
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/4image.png",
        url: "https://hcb.hackclub.com/zephyr",
        overlay_color: "#3c7d80",
        object_position: "center"
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/5image.png",
        url: "https://hcb.hackclub.com/hackpenn",
        overlay_color: "#225c80",
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/6image.png",
        url: "https://hcb.hackclub.com/wild-wild-west",
        overlay_color: "#6c2280",
      },
      {
        image: "https://cloud-e3evhlxgo-hack-club-bot.vercel.app/7image.png",
        url: "https://hcb.hackclub.com/hq",
        overlay_color: "#802434",
      }
    ]
  end

  private

  def get_user_color(id)
    alphabet = ("A".."Z").to_a
    colors = ["ec3750", "ff8c37", "f1c40f", "33d6a6", "5bc0de", "338eda"]
    colors[id.to_i % colors.length] || colors.last
  end
end
