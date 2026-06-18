# frozen_string_literal: true

# Public marketing landing pages (e.g. /for/funders).
#
# These pages are intentionally outside the authenticated app shell: they skip the
# global sign-in requirement and Pundit authorization, render with the lightweight
# "marketing" layout, and are safe to index. The page bodies are fully static — the
# only dynamic behavior is the funder inquiry form, which emails the operations team.
class MarketingController < ApplicationController
  skip_before_action :signed_in_user
  skip_before_action :redirect_to_onboarding
  skip_after_action :verify_authorized # not Pundit-managed

  invisible_captcha only: [:funder_inquiry], honeypot: :subtitle

  after_action :allow_indexing, only: [:funders]

  # Gates just the "Funders on HCB" testimonials section, so the page can ship while we
  # await sign-off on the funder quotes. Enable once the quotes are approved.
  TESTIMONIALS_FLAG = :funders_landing_testimonials

  FUNDER_STATS_CACHE_KEY = "marketing/funder_stats"

  def funders
    @stats = funder_stats
    @show_testimonials = Flipper.enabled?(TESTIMONIALS_FLAG, current_user)
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
      flash[:funder_form] = { "name" => name, "email" => email, "message" => message }
      return redirect_to funders_path(anchor: "talk-to-us")
    end

    FunderInquiryMailer.with(name:, email:, message:).inquiry.deliver_later

    # Log the lead so it is never lost if mail delivery later fails.
    Rails.logger.info("[funder_inquiry] new inquiry email=#{email.inspect} name=#{name.inspect}")

    # Use flash (not a query param) so a shared link never shows the confirmation card.
    flash[:funder_inquiry] = "received"
    redirect_to funders_path(anchor: "talk-to-us")
  end

  private

  # Headline figures for the funders page, computed live and cached so the page never
  # runs heavy aggregates inline.
  #
  # TODO(stats): confirm the exact scopes/formatting with the team before launch, and
  # wire `countries` to a real source (currently a placeholder).
  def funder_stats
    Rails.cache.fetch(FUNDER_STATS_CACHE_KEY, expires_in: 12.hours) do
      {
        moved: humanized_money(CanonicalTransaction.included_in_stats.sum("ABS(amount_cents)")),
        organizations: humanized_count(Event.where(demo_mode: false).count),
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
