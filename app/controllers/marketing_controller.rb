# frozen_string_literal: true

# Public marketing landing pages (e.g. /for/funders).
#
# These pages are intentionally outside the authenticated app shell: they skip the
# global sign-in requirement and Pundit authorization, render with the lightweight
# "marketing" layout, and are safe to index. The page bodies are fully static. The
# only dynamic behavior is the inquiry forms, which email the team.
class MarketingController < ApplicationController
  skip_before_action :signed_in_user
  skip_before_action :redirect_to_onboarding
  skip_after_action :verify_authorized # not Pundit-managed

  invisible_captcha only: [:funder_inquiry, :ai_safety_inquiry], honeypot: :subtitle

  # The app default is null_session, which still runs the action on a bad token.
  # These forms send email, so refuse cross-site posts outright.
  protect_from_forgery with: :exception, only: [:funder_inquiry, :ai_safety_inquiry]

  rescue_from ActionController::InvalidAuthenticityToken do
    flash[:error] = "Your session expired. Please send your message again."
    redirect_to(action_name == "funder_inquiry" ? funders_path(anchor: "talk-to-us") : ai_safety_path(anchor: "talk-to-us"))
  end

  after_action :allow_indexing, only: [:funders, :funders_faq, :ai_safety]

  # Gates just the "Funders on HCB" testimonials section, so the page can ship while we
  # await sign-off on the funder quotes. Enable once the quotes are approved.
  TESTIMONIALS_FLAG = :funders_landing_testimonials

  # Gates the Public Grids recipient story, so it can switch on independently of the rest
  # of the page once its content is approved.
  PUBLIC_GRIDS_FLAG = :funders_landing_public_grids

  # Gates the redesigned comparison table and the funder FAQ (the on-page "Common questions" teaser
  # plus the /for/funders/faq subpage). Lets the new work ship dark and switch on when approved.
  # When off, the page falls back to the original static comparison table and the FAQ subpage 404s.
  COMPARISON_FAQ_FLAG = :funders_landing_comparison_faq

  FUNDER_STATS_CACHE_KEY = "marketing/funder_stats"

  def funders
    @stats = funder_stats
    @show_testimonials = Flipper.enabled?(TESTIMONIALS_FLAG, current_user)
    @show_public_grids = Flipper.enabled?(PUBLIC_GRIDS_FLAG, current_user)
    @show_comparison_faq = Flipper.enabled?(COMPARISON_FAQ_FLAG, current_user)
    @skip_layout_og_tags = true # page provides its own funder-specific meta
  end

  # Dedicated funder FAQ subpage (the main /for/funders page links here from its short
  # "Common questions" block). Static, indexable, same marketing layout.
  def funders_faq
    # Gated: the FAQ subpage isn't reachable unless the user has the flag.
    return head :not_found unless Flipper.enabled?(COMPARISON_FAQ_FLAG, current_user)

    @stats = funder_stats # the FAQ cites live platform figures ($ moved, organizations)
    @skip_layout_og_tags = true # page provides its own funder-specific meta
  end

  def funder_inquiry
    # Bot submissions are rejected upstream by invisible_captcha (honeypot: :subtitle).
    email = params[:email].to_s.strip
    name = params[:name].to_s.strip
    message = params[:message].to_s.strip

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      flash[:error] = "Please enter a valid email address."
      # Carry the submitted values back so the form isn't cleared on the error redirect.
      # Capped so a long message can't overflow the 4 KB session cookie.
      flash[:funder_form] = { "name" => name.first(100), "email" => email.first(254), "message" => message.byteslice(0, 1_000).scrub("") }
      return redirect_to funders_path(anchor: "talk-to-us")
    end

    FunderInquiryMailer.with(name:, email:, message:).inquiry.deliver_later

    # Log the lead so it is never lost if mail delivery later fails.
    Rails.logger.info("[funder_inquiry] new inquiry")

    # Use flash (not a query param) so a shared link never shows the confirmation card.
    flash[:funder_inquiry] = "received"
    redirect_to funders_path(anchor: "talk-to-us")
  end

  def ai_safety
    @stats = funder_stats
    @audience = MarketingInquiry::AUDIENCES.key?(params[:audience]) ? params[:audience] : "team"
    @ref = sanitized_ref(params[:ref])
    @skip_layout_og_tags = true # page provides its own meta

    respond_to do |format|
      format.html
      # /for/ai-safety.md, for pasting into or pointing an LLM at.
      format.md { render plain: ai_safety_markdown, content_type: "text/markdown" }
    end
  end

  def ai_safety_inquiry
    # Bot submissions are rejected upstream by invisible_captcha (honeypot: :subtitle).
    inquiry = params[:ai_safety_inquiry]
    inquiry = {} unless inquiry.is_a?(ActionController::Parameters) # a crafted scalar would raise
    name = inquiry[:name].to_s.gsub(/[[:cntrl:]]/, " ").squish.first(100)
    email = inquiry[:email].to_s.strip.first(254)
    message = inquiry[:message].to_s.gsub(/[^\P{Cc}\n\t]/, "").strip.first(5_000)
    audience = MarketingInquiry::AUDIENCES.key?(inquiry[:audience]) ? inquiry[:audience] : nil
    ref = sanitized_ref(inquiry[:ref])

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      flash[:error] = "Please enter a valid email address."
      # Carry the values back so the form isn't cleared. The message is capped so the
      # 4 KB session cookie can't overflow.
      flash[:ai_safety_form] = {
        "name" => name, "email" => email, "audience" => audience,
        "message" => message.byteslice(0, 1_000).scrub(""), "ref" => ref
      }
      return redirect_to ai_safety_path({ audience:, ref:, anchor: "talk-to-us" }.compact)
    end

    # Never lose the lead: a failed save is logged and the emails still go out.
    record = begin
      MarketingInquiry.create(page: "ai_safety", name: name.presence, email:, audience:, message: message.presence, ref:)
    rescue => e
      Rails.error.report(e)
      nil
    end
    Rails.logger.warn("[ai_safety_inquiry] not saved: #{record.errors.full_messages.to_sentence}") if record && !record.persisted?

    mail = AiSafetyInquiryMailer.with(name:, email:, audience:, message:, ref:)
    mail.confirmation.deliver_later
    mail.notify_team.deliver_later

    Rails.logger.info("[ai_safety_inquiry] id=#{record&.id || "none"} audience=#{audience} ref=#{ref}")

    flash[:ai_safety_inquiry] = "received"
    redirect_to ai_safety_path(anchor: "talk-to-us")
  end

  private

  # The page's own HTML as Markdown, so the two never drift. Drops navigation, the
  # calls to action, and the form, which mean nothing outside the page.
  def ai_safety_markdown
    page = Nokogiri::HTML5.fragment(render_to_string(:ai_safety, layout: false, formats: [:html]))
    page.css("script, style, nav, form, img, .mk-ais-cta, .mk-ais-ask, .mk-ais__contact").each(&:remove)
    url = ai_safety_url(host: Rails.application.routes.default_url_options[:host], protocol: "https")

    # ReverseMarkdown glues these together, so give them plain structure first.
    page.css("caption").each do |caption|
      caption.name = "h2"
      caption.parent.add_previous_sibling(caption)
    end
    page.css("dt").each { |term| term.name = "h3" }
    page.css("dd").each { |definition| definition.name = "p" }
    page.css("li > h3").each { |step| step.name = "strong" }
    page.css("li > p").each do |text|
      text.name = "span"
      text.add_previous_sibling(" ")
    end
    page.css(".mk-ais__cta > *").each { |action| action.wrap("<p></p>") }
    page.css("a[href^='#'], a[href^='/']").each { |link| link["href"] = URI.join(url, link["href"]).to_s }

    "Source: #{url}\n\n#{ReverseMarkdown.convert(page.to_html, unknown_tags: :bypass, github_flavored: true).strip}\n"
  end

  def sanitized_ref(raw)
    raw.to_s.downcase if raw.is_a?(String) && raw.match?(/\A[a-z0-9_-]{1,64}\z/i)
  end

  # Headline figures for the funders page, computed live and cached so the page never
  # runs heavy aggregates inline.
  #
  # TODO(stats): confirm the exact scopes/formatting with the team before launch, and
  # wire `countries` to a real source (currently a placeholder).
  def funder_stats
    Rails.cache.fetch(FUNDER_STATS_CACHE_KEY, expires_in: 12.hours) do
      {
        moved: humanized_money(CanonicalTransaction.included_in_stats.sum("ABS(amount_cents)")),
        organizations: humanized_count(Event.not_omitted.not_hidden.not_demo_mode.approved.count),
        countries: "40+", # TODO(stats): compute from a real country source
        founded: "2018",
      }
    end
  end

  # Floors to a round figure so the trailing "+" is always truthful (e.g. "$143M+").
  def humanized_money(cents)
    dollars = cents.to_i / 100

    if dollars >= 1_000_000_000
      "$#{(dollars / 100_000_000) / 10.0}B+"
    elsif dollars >= 1_000_000
      "$#{dollars / 1_000_000}M+"
    elsif dollars >= 1_000
      "$#{dollars / 1_000}K+"
    else
      "$#{dollars}"
    end
  end

  # Floors a count to two significant figures (e.g. 5_234 -> "5,200+").
  def humanized_count(count)
    return count.to_s if count < 1_000

    unit = 10**(Math.log10(count).floor - 1)
    floored = (count / unit) * unit
    "#{ActiveSupport::NumberHelper.number_to_delimited(floored)}+"
  end

  def allow_indexing
    response.delete_header("X-Robots-Tag")
  end

end
