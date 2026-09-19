# frozen_string_literal: true

module Admin
  # Break-glass: lets an admin open a PagerDuty incident against the engineering
  # on-call escalation policy when something urgent is wrong with HCB.
  class EngineeringPagesController < ApplicationController
    skip_after_action :verify_authorized # do not force pundit

    # ApplicationController's bare `protect_from_forgery` resolves to
    # :null_session, which doesn't sign the request out here (Current.session is
    # already loaded from the cookie by then). Waking a human deserves a real
    # token check.
    protect_from_forgery with: :exception

    # NOTE: deliberately *not* the usual `signed_in_admin`, which only requires
    # `auditor?`. Paging wakes a human up, so it's gated on `admin?`.
    before_action :signed_in_true_admin

    # /admin is excluded from the global Rack::Attack throttle, so this is the
    # only ceiling. Set well above what a real incident needs: the first page
    # always goes through, but a stuck retry loop can't ring the phone forever.
    rate_limit to: 5, within: 5.minutes, only: :create,
               by: -> { current_user&.id },
               with: -> { redirect_to admin_tools_path, flash: { error: "You've paged several times in the last few minutes. Someone has already been notified. Contact an engineer directly if it's urgent." } }

    layout "admin"

    MAX_MESSAGE_LENGTH = 120
    CONFIRMATION_PHRASE = "PAGE"

    def new
    end

    def create
      @message = params[:message].to_s.strip

      return refuse("Tell the on-call engineer what's happening.") if @message.blank?

      if @message.length > MAX_MESSAGE_LENGTH
        return refuse("Keep it under #{MAX_MESSAGE_LENGTH} characters so it fits in a phone notification.")
      end

      # Also enforced client-side by the type-to-confirm Stimulus controller,
      # but that's only a convenience. This is the guard that actually holds.
      unless params[:confirmation].to_s.strip == CONFIRMATION_PHRASE
        return refuse("Type #{CONFIRMATION_PHRASE} to confirm you want to wake someone up.")
      end

      unless PagerDutyService.manual_page_enabled?
        return refuse("PagerDuty isn't configured in this environment, so nobody was paged.")
      end

      result = PagerDutyService.trigger(
        routing_key: PagerDutyService.manual_page_routing_key,
        summary: page_summary,
        source: page_source,
        severity: "critical",
        client_url: root_url,
        component: "hcb",
        group: "manual",
        klass: "manual_page",
        custom_details: page_custom_details,
        links: [{ href: user_url(current_user), text: "#{current_user.name} on HCB" }]
      )

      # Deliberately "accepted", not "paged". A 202 only proves PagerDuty took
      # the event. Whether a phone actually rings depends on the escalation
      # policy, the on-call user's notification rules, and alert grouping, none
      # of which a write-only routing key lets us read back.
      redirect_to admin_tools_path, flash: { success: "PagerDuty accepted the page (ref #{result["dedup_key"]}). If nobody reaches out within a few minutes, contact an engineer directly." }
    rescue Faraday::TimeoutError => e
      # A read timeout: the request went out but no response came back, so the
      # event may well have been enqueued and someone may already be dialing.
      # Saying "nobody was notified" here would send the admin off to wake a
      # second person for no reason. A failure to connect at all is a different
      # error (Faraday::ConnectionFailed) and falls through to the branch below,
      # where "nobody was notified" is accurate.
      report_failure(e)
      flash.now[:error] = "PagerDuty didn't respond in time, so we can't confirm the page went out. It may have fired anyway. If nobody reaches out within a few minutes, contact an engineer directly."
      render :new, status: :bad_gateway
    rescue => e
      # Broad on purpose. Every path out of here tells the admin nobody was
      # paged, which is the truthful and safe answer for any unexpected error.
      report_failure(e)
      flash.now[:error] = "PagerDuty didn't accept the page, so nobody was notified. Contact an engineer directly."
      render :new, status: :bad_gateway
    end

    private

    def refuse(message)
      flash.now[:error] = message
      render :new, status: :unprocessable_content
    end

    # This is the whole thing the on-call engineer sees on their lock screen, so
    # the message leads and the attribution trails (push notifications truncate).
    def page_summary
      summary = "#{@message} · paged by #{current_user.name}"
      summary = "[#{Rails.env}] #{summary}" unless Rails.env.production?
      summary
    end

    # The configured host rather than request.host, which is attacker-influenced
    # via the Host header and is what on-call reads to tell staging from prod.
    def page_source
      Rails.application.routes.default_url_options[:host].presence || "hcb"
    end

    def page_custom_details
      details = {
        paged_by: current_user.name,
        paged_by_email: current_user.email,
        environment: Rails.env,
        message: @message
      }
      # Otherwise on-call calls back the impersonated user, not the real actor.
      if current_session&.impersonated?
        details[:impersonated_by] = current_session.impersonated_by&.email
      end
      details
    end

    def report_failure(error)
      Rails.logger.error("[page_engineers] failed to page on-call: #{error.class}: #{error.message}")
      Rails.error.report(
        error,
        handled: false,
        severity: :error,
        context: {
          paged_by_id: current_user&.id,
          response_status: error.try(:response_status)
        }
      )
    end

    def signed_in_true_admin
      return if admin_signed_in?

      # Auditors can see the nav item and the admin tools card, so send them
      # somewhere useful instead of bouncing them to a sign-in screen they're
      # already past.
      if signed_in?
        redirect_to admin_tools_path, flash: { error: "Only admins can page the on-call engineer. Ask an admin, or post in Slack." }
      else
        redirect_to auth_users_path(require_reload: true), flash: { error: "You’ll need to sign in as an admin." }
      end
    end

  end
end
