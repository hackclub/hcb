# frozen_string_literal: true

module ApplicationHelper
  include ActionView::Helpers

  def render_money(amount, opts = {})
    amount = amount.cents if amount.is_a?(Money)

    unit = opts[:unit] || "$"
    trunc = opts[:trunc] || false

    num = BigDecimal((amount || 0).to_s) / 100
    if trunc
      if num >= 1_000_000
        "#{number_to_currency(num / 1_000_000, precision: 1, unit:)}m"
      elsif num >= 1_000
        "#{number_to_currency(num / 1_000, precision: 1, unit:)}k"
      else
        number_to_currency(num, unit:)
      end
    else
      number_to_currency(num, unit:)
    end
  end

  def render_money_short(amount, opts = {})
    render_money(amount, opts).remove(".00")
  end

  def render_money_amount(amount, opts = {})
    opts[:unit] = ""
    render_money(amount, opts)
  end

  def render_transaction_amount(amount)
    if amount > 0
      content_tag(:span, "+#{render_money amount}", class: "success-dark medium")
    else
      render_money amount
    end
  end

  def render_percentage(decimal, params = {})
    precision = params[:precision] || 2
    number_to_percentage(decimal * 100, precision:)
  end

  def render_address(obj)
    content = []
    content << [obj.address_line1, tag.br].join("")
    content << [obj.address_line2 + tag.br].join("") if obj.address_line2.present?
    content << [obj.address_city, obj.address_state, obj.address_postal_code].join(", ")
    content_tag(:span, content.join.html_safe)
  end

  def async_frame_to(url, options = { as: :div }, &block)
    content_tag options[:as].to_sym,
                block_given? ? capture(&block) : nil,
                data: {
                  src: url,
                  behavior: "async_frame",
                  loading: options[:lazy] ? "lazy" : nil
                },
                **options
  end

  def blankslate(text, options = {})
    other_options = options.except(:class)
    content_tag(:p, text, class: "center mt0 mb0 pt4 pb4 slate bold h3 mx-auto rounded-lg border #{options[:class]}", **other_options)
  end

  def list_badge_for(count, item, glyph, options = { optional: false, required: false })
    return nil if options[:optional] && count == 0

    icon = inline_icon(glyph, size: 20, 'aria-hidden': true)

    content_tag(:span,
                icon + count.to_s,
                'aria-label': pluralize(count, item),
                class: "list-badge tooltipped tooltipped--w #{options[:required] && count == 0 ? 'b--warning warning' : ''} #{options[:class]}")
  end

  def badge_for(value, options = {})
    content_tag :span, value, class: "badge #{options[:class]} #{'bg-muted' if [0, "Pending"].include?(value)}"
  end

  def status_badge(type = :pending)
    content_tag :span, "", class: "status bg-#{type}"
  end

  def status_if(type, condition)
    status_badge(type) if condition
  end

  def pop_icon_to(icon, url, options = { class: "info" })
    link_to url, options.merge(class: "pop #{options[:class]}") do
      inline_icon icon, size: 28
    end
  end

  def no_app_shell
    @no_app_shell = true
  end

  def no_transparency_header
    @no_transparency_header = true
  end

  def form_errors(model, name = nil, prefix = "We couldn't save this")
    return if model.errors.none?

    name ||= model.class.name.underscore.humanize.downcase

    errors_list = content_tag :ul do
      model.errors.full_messages.map do |message|
        concat(content_tag(:li, message))
      end
    end

    content_tag :div, class: "error-card", data: { turbo_temporary: true } do
      content_tag(:h2, "#{prefix} #{name} because of #{pluralize(model.errors.size, 'error')}.") +
        errors_list
    end
  end

  def modal_close
    pop_icon_to "view-close", "#close_modal", class: "modal__close muted", rel: "modal:close", tabindex: 0
  end

  def modal_external_link(external_link)
    pop_icon_to "external", external_link, target: "_blank", size: 14, class: "modal__external muted", onload: "window.navigator.standalone ? this.setAttribute('target', '_top') : null"
  end

  def modal_header(text, external_link: nil)
    content_tag :header, class: "pb2" do
      modal_close +
        (external_link ? modal_external_link(external_link) : "") +
        content_tag(:h2, text.html_safe, class: "h1 mt0 mb0 pb0 border-none")
    end
  end

  def carousel(content, current_slide, &block)
    content_tag :div, class: "carousel", data: { "controller": "carousel", "carousel-target": "carousel", "carousel-slide-value": current_slide.to_s, "carousel-length-value": content.length.to_s } do
      (content_tag :button, class: "carousel__button carousel__button--left pop", data: { "carousel-target": "left" } do
        inline_icon "view-back", size: 40
      end) +
        (content_tag :div, class: "carousel__items" do
          (content.map.with_index do |item, index|
            content_tag :div, class: "carousel__item #{index == current_slide ? 'carousel__item--active' : ''}" do
              block.call(item, index)
            end
          end).join.html_safe
        end) +
        (content_tag :button, class: "carousel__button carousel__button--right pop", data: { "carousel-target": "right" } do
          inline_icon "view-back", size: 40
        end)
    end
  end

  def relative_timestamp(time, options = {})
    content_tag :span, "#{options[:prefix]}#{time_ago_in_words time} ago#{options[:suffix]}", options.merge(title: time)
  end

  def auto_link_new_tab(text)
    auto_link(text, html: { target: "_blank" })
  end

  def debug_obj(item)
    content_tag :pre, pp(item.attributes.to_yaml)
  end

  def inline_icon(filename, options = {})
    # cache parsed SVG files to reduce file I/O operations
    @icon_svg_cache ||= {}
    if !@icon_svg_cache.key?(filename)
      file = File.read(Rails.root.join("app", "assets", "images", "icons", "#{filename}.svg"))
      @icon_svg_cache[filename] = Nokogiri::HTML::DocumentFragment.parse file
    end

    doc = @icon_svg_cache[filename].dup
    svg = doc.at_css "svg"
    options[:style] ||= ""
    if options[:size]
      options[:width] ||= options[:size]
      options[:height] ||= options[:size]
      options.delete :size
    end
    options.each { |key, value| svg[key.to_s] = value }
    doc.to_html.html_safe
  end

  def merchant_icon(yellow_pages_merchant, **options)
    @icon_svg_cache ||= {}

    unless @icon_svg_cache.key?(yellow_pages_merchant)
      icon = yellow_pages_merchant.icon
      @icon_svg_cache[yellow_pages_merchant] = icon.present? ? Nokogiri::HTML::DocumentFragment.parse(icon) : nil
    end

    icon = @icon_svg_cache[yellow_pages_merchant]
    return nil if icon.nil?

    doc = icon.dup
    svg = doc.at_css "svg"
    options[:style] ||= ""
    if options[:size]
      options[:width] ||= options[:size]
      options[:height] ||= options[:size]
      options.delete(:size)
    end
    options.each { |key, value| svg[key.to_s] = value }
    doc.to_html.html_safe
  end

  def anchor_link(id)
    link_to "##{id}", class: "absolute top-0 -left-8 transition-opacity opacity-0 group-hover/summary:opacity-100 group-target/item:opacity-100 anchor-link tooltipped tooltipped--s", 'aria-label': "Copy link", data: { turbo: false, controller: "clipboard", clipboard_text_value: url_for(only_path: false, anchor: id), action: "clipboard#copy" } do
      inline_icon "link", size: 28
    end
  end

  def help_message
    content_tag :span, "Contact the HCB team at #{help_email} or #{help_phone}.".html_safe
  end

  def help_email
    mail_to "hcb@hackclub.com", class: "nowrap"
  end

  def help_phone
    phone_to "+18442372290", "+1 (844) 237 2290", class: "nowrap"
  end

  def format_date(date)
    if date.nil?
      Airbrake.notify("Hey! date is nil here")
      return nil
    end

    local_time(date, "%b %e, %Y")
  end

  def format_datetime(datetime)
    local_time(datetime, "%b %e, %Y, %l:%M %p")
  end

  def home_action_size
    @home_size.to_i > 48 ? 36 : 28
  end

  def page_xl
    content_for(:container_class) { "container--xl" }
  end

  def page_md
    content_for(:container_class) { "container--md" }
  end

  def page_sm
    content_for(:container_class) { "container--sm" }
  end

  alias_method :page_narrow, :page_sm

  def page_xs
    content_for(:container_class) { "container--xs" }
  end

  alias_method :page_extranarrow, :page_xs

  def title(text)
    content_for :title, text
  end

  def commit_name
    @short_hash ||= commit_hash[0...7]
    @commit_name ||= begin
      if commit_dirty?
        "#{@short_hash}-dirty"
      else
        @short_hash
      end
    end
  end

  def commit_dirty?
    ::Util.commit_dirty?
  end

  def commit_hash
    ::Util.commit_hash
  end

  def commit_time
    @commit_time ||= begin
      heroku_time = ENV["HEROKU_RELEASE_CREATED_AT"]
      git_time = `git log -1 --format=%at 2> /dev/null`.chomp

      return nil if heroku_time.blank? && git_time.blank?

      heroku_time.blank? ? git_time.to_i : Time.parse(heroku_time)
    end

    @commit_time
  end

  def commit_duration
    @commit_duration ||= begin
      return nil if commit_time.nil?

      distance_of_time_in_words Time.at(commit_time), Time.now
    end
  end

  module_function :commit_hash, :commit_time

  def admin_inspectable_attributes(record)
    stripe_obj = begin
      record.stripe_obj
    rescue Stripe::InvalidRequestError
      puts "Can't access stripe object, skipping"
    rescue NoMethodError
      puts "Not a stripe object, skipping"
    end

    if stripe_obj.nil?
      record
    else
      result = {}
      result[record.class] = record
      result["stripe_obj"] = stripe_obj

      result
    end
  end

  def development_mode_flavor
    [
      "Drop the tables for all I care.",
      "More, tonight at 9.",
      "Go wild.",
      "But, the night is still young.",
      "You coward.",
      "Now go write some code?",
      "AKA a world of pure imagination"
    ].sample
  end

  def tooltipped_logo?
    !Rails.env.production? || user_birthday?
  end

  require "json"

  def json(obj)
    JSON.pretty_generate(obj.as_json)
  end

  def airtable_form(id, params = {}, hide = [])
    query = {}
    params.each do |key, value|
      query["prefill_#{key}"] = value
    end
    hide.each do |field|
      query["hide_#{field}"] = "true"
    end

    "https://airtable.com/#{id}?#{URI.encode_www_form(query)}"
  end

  def fillout_form(id, params = {}, prefix: "")
    query = params.transform_keys { |k| prefix + k }
    "https://forms.hackclub.com/t/#{id}?#{URI.encode_www_form(query)}"
  end

  def redacted_amount
    tag.span class: "tooltipped tooltipped--w", style: "cursor: default", "aria-label": "Hidden for security" do
      tag.span(style: "filter: blur(5px)") { "$0.00" }
    end
  end

  def copy_to_clipboard(clipboard_value, tooltip_direction: "n", **options, &block)
    # If block is not given, use clipboard_value as the rendered content
    block ||= ->(_) { clipboard_value }
    return yield if options.delete(:if) == false

    css_classes = "pointer tooltipped tooltipped--#{tooltip_direction} #{options.delete(:class)}"
    tag.span "data-controller": "clipboard", "data-clipboard-text-value": clipboard_value, class: css_classes, "aria-label": "Click to copy", "data-action": "click->clipboard#copy", **options, &block
  end

  def settings_tab(active: false, &block)
    if active
      tag.li(class: "active", data: { controller: "scroll-into-view" }, &block)
    else
      tag.li(&block)
    end
  end

  def possessive(name)
    name + (name.ends_with?("s") ? "'" : "'s")
  end

end
