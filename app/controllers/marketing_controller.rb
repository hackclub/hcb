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

  # Gated behind a Flipper flag during rollout: anyone without it 404s. Flip the flag on
  # per-user (or boolean-enable it globally to make the page public at launch).
  before_action :require_funders_access

  after_action :allow_indexing, only: [:funders]

  FUNDERS_FLAG = :funders_landing_page

  FUNDER_STATS_CACHE_KEY = "marketing/funder_stats"

  def funders
    @stats = funder_stats
    @skip_layout_og_tags = true # page provides its own funder-specific meta
  end

  def funder_inquiry
    # Honeypot: bots fill hidden fields. Pretend success without sending.
    return redirect_to funders_path(inquiry: "received") if params[:company].present?

    email = params[:email].to_s.strip
    name = params[:name].to_s.strip
    message = params[:message].to_s.strip

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      flash[:error] = "Please enter a valid email address."
      return redirect_to funders_path(inquiry: "error", anchor: "talk-to-us")
    end

    FunderInquiryMailer.with(name:, email:, message:).inquiry.deliver_later

    # Log the lead so it is never lost if mail delivery later fails.
    Rails.logger.info("[funder_inquiry] new inquiry email=#{email.inspect} name=#{name.inspect}")

    redirect_to funders_path(inquiry: "received", anchor: "talk-to-us")
  end

  private

  def require_funders_access
    not_found unless Flipper.enabled?(FUNDERS_FLAG, current_user)
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
