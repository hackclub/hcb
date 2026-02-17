# frozen_string_literal: true

require "digest/md5"
require "cgi"

module UsersHelper
  def users_mobile_nav(selected: nil)
    items = [
      {
        name: "Home",
        path: root_path,
        icon: "home",
        tooltip: "See all your organizations",
        selected: selected == :home
      },
      (if current_user.followed_events.any?
         {
           name: "Feed",
           path: my_feed_path,
           tooltip: "See announcements for organizations you're following",
           icon: "announcement",
           selected: selected == :feed
         }
       else
         nil
       end),
      {
        name: "Cards",
        path: my_cards_path,
        icon: "card",
        tooltip: "See all your cards",
        selected: selected == :cards,
      },
      {
        name: "Receipts",
        path: my_inbox_path,
        icon: "receipt",
        tooltip: "See transactions awaiting receipts",
        selected: selected == :receipts,
        async_badge: my_missing_receipts_icon_path,
      },
      {
        name: "Reimbursements",
        path: my_reimbursements_path,
        icon: "reimbursement",
        tooltip: "See expense reimbursements",
        async_badge: my_reimbursements_icon_path,
        selected: selected == :reimbursements
      },
    ].compact

    if current_user.jobs.any?
      items << {
        name: "Pay",
        path: my_payroll_path,
        icon: "person-badge",
        tooltip: "Submit invoices & get paid",
        selected: selected == :payroll
      }
    end

    items
  end

  def gravatar_url(email, name, id, size)
    email ||= "bank@hackclub.com"

    name ||= begin
      temp = email.split("@").first.split(/[^a-z\d]/i).compact_blank
      temp.length == 1 ? temp.first.first(2) : temp.first(2).map(&:first).join
    end
    hex = Digest::MD5.hexdigest(email.downcase.strip)
    "https://gravatar.com/avatar/#{hex}?s=#{size}&d=https%3A%2F%2Fui-avatars.com%2Fapi%2F/#{CGI.escape(name)}/#{size}/#{get_user_color(id)}/fff"
  end

  def profile_picture_for(user, size = 24, default_image: nil)
    default_image ||= "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/1e41035b85ccb92f_image.png"

    # profile_picture_for works with OpenStructs (used on the front end when a user isn't registered),
    # so this method shows Gravatars/intials for non-registered and allows showing of uploaded profile pictures for registered users.
    if user.nil?
      default_image
    elsif Rails.env.production? && user.is_a?(User) && user.profile_picture&.persisted?
      Rails.application.routes.url_helpers.url_for(
        user.profile_picture.variant(
          thumbnail: "#{size * 2}x#{size * 2}^",
          gravity: "center",
          extent: "#{size * 2}x#{size * 2}"
        )
      )
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

  def avatar_for(user, size: 24, click_to_mention: false, default_image: nil, **options)
    src = profile_picture_for(user, size, default_image:)
    current_user = defined?(current_user) ? current_user : nil

    klasses = ["rounded-full", "shrink-none"]
    klasses << "avatar--current-user" if user && user == current_user
    klasses << options[:class] if options[:class]
    klass = klasses.join(" ")

    alt = options[:alt]
    alt ||= current_user_flavor_text.sample if user == current_user
    alt ||= user&.initials
    alt ||= ""

    options[:data] = (options[:data] || {}).merge(behavior: "mention", mention_value: "@#{user.email}") if click_to_mention && user

    image_tag(src, options.merge(loading: "lazy", alt:, width: size, height: size, class: klass))
  end

  def user_mention(user, default_name: "No User", click_to_mention: false, comment_mention: false, default_image: nil, **options)
    name = content_tag :span, (user&.initial_name || default_name)
    viewer = defined?(current_user) ? current_user : nil
    avi = avatar_for(user, click_to_mention:, default_image:, **(options[:avatar] || {}))

    klasses = ["mention"]
    klasses << %w[mention--admin tooltipped tooltipped--n] if user&.auditor? && !options[:disable_tooltip]
    klasses << %w[mention--current-user tooltipped tooltipped--n] if viewer && (user&.id == viewer.id) && !options[:disable_tooltip]
    klasses << %w[badge bg-muted ml0] if comment_mention
    klasses << options[:class] if options[:class]
    klass = klasses.uniq.join(" ")

    aria_label = if options[:aria_label]
                   options[:aria_label]
                 elsif user.nil?
                   "No user found"
                 elsif user.id == viewer&.id
                   current_user_flavor_text.sample
                 elsif user.admin?
                   "#{user.name} is an admin"
                 elsif user.auditor?
                   "#{user.name} is an auditor"
                 end

    content = if user&.auditor? && !options[:hide_avatar]
                bolt = inline_icon "admin-badge", size: 20
                avi + bolt + name
              elsif options[:hide_avatar]
                name
              else
                avi + name
              end

    if user && viewer&.auditor?
      button = content_tag(
        :span,
        content,
        class: "*:align-middle menu__toggle menu__toggle--arrowless overflow-visible mention__menu-btn",
        data: {
          "menu-target": "toggle",
          action: "contextmenu->menu#toggle click@document->menu#close keydown@document->menu#keydown"
        },
      )

      aria_label = [aria_label, "Right click for admin tools"].compact.join(" | ")

      # Menu content items
      menu_items = safe_join([
                               content_tag(
                                 :span,
                                 safe_join([inline_icon("email", size: 16), content_tag(:span, "Email", class: "ml1")]),
                                 onclick: "window.open('mailto:#{user.email}'); return false;",
                                 class: "menu__item menu__item--icon menu__action", rel: "noopener"
                               ),
                               #  copy to clipboard
                               content_tag(
                                 :span,
                                 safe_join([inline_icon("copy", size: 16), content_tag(:span, "Copy email", class: "ml1")]),
                                 onclick: "navigator.clipboard.writeText('#{user.email}');alert('Copied!'); return false;",
                                 class: "menu__item menu__item--icon menu__action", rel: "noopener"
                               ),
                               content_tag(
                                 :span,
                                 nil,
                                 class: "menu__divider"
                               ),
                               content_tag(
                                 :span,
                                 safe_join([inline_icon("settings", size: 16), content_tag(:span, "Settings", class: "ml1")]),
                                 onclick: "window.open('#{admin_user_url(user)}', '_blank'); return false;",
                                 class: "menu__item menu__item--icon menu__action", rel: "noopener"
                               )
                             ])

      menu_content = content_tag(
        :span,
        menu_items,
        class: "menu__content menu__content--2 menu__content--compact h5",
        data: { "menu-target": "content" }
      )

      menu_wrapper = content_tag(
        :span,
        button + menu_content,
        data: { controller: "menu", "menu-placement-value": "bottom-start" },
        class: "mention__menu"
      )

      content = menu_wrapper
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

  def creator_bar(object, **options)
    creator = if defined?(object.creator)
                object.creator
              elsif defined?(object.sender)
                object.sender
              else
                object.user
              end
    mention = user_mention(creator, default_name: "Anonymous User", **options)
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
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/f00f504836b546b6_image.png",
        url: "https://hcb.hackclub.com/zephyr",
        overlay_color: "#802434",
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/8e36b998e8f8a014_image.png",
        url: "https://hcb.hackclub.com/the-charlotte-bridge",
        overlay_color: "#805b24",
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/c2b21fc2bac8fe37_image.png",
        url: "https://hcb.hackclub.com/windyhacks",
        overlay_color: "#807f0a",
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/3693a52722bd453d_image.png",
        url: "https://hcb.hackclub.com/the-innovation-circuit",
        overlay_color: "#22806c",
        object_position: "center"
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/0dd4665e1f416fe0_image.png",
        url: "https://hcb.hackclub.com/zephyr",
        overlay_color: "#3c7d80",
        object_position: "center"
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/014152a92bec1ca3_image.png",
        url: "https://hcb.hackclub.com/hackpenn",
        overlay_color: "#225c80",
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/17c73dbb7921ea42_image.png",
        url: "https://hcb.hackclub.com/wild-wild-west",
        overlay_color: "#6c2280",
      },
      {
        image: "https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/395d07060854ce95_image.png",
        url: "https://hcb.hackclub.com/assemble",
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
