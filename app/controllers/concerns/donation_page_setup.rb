# frozen_string_literal: true

# app/controllers/concerns/donation_page_setup.rb
module DonationPageSetup
  extend ActiveSupport::Concern

  def build_donation_page!(event:, params:, request:)
    unless event.donation_page_available?
      return not_found
    end

    tax_deductible = params[:goods].nil? || params[:goods] == "0"

    @tiers = event.donation_tiers.where(published: true)
    @show_tiers = event.donation_tiers_enabled? && @tiers.any?

    @donation = Donation.new(
      name: params[:name] || (organizer_signed_in? ? nil : current_user&.name),
      email: params[:email] || (organizer_signed_in? ? nil : current_user&.email),
      amount: params[:amount],
      message: params[:message],
      fee_covered: params[:fee_covered],
      event: event,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      tax_deductible:,
      referrer: request.referrer,
      utm_source: params[:utm_source],
      utm_medium: params[:utm_medium],
      utm_campaign: params[:utm_campaign],
      utm_term: params[:utm_term],
      utm_content: params[:utm_content]
    )

    @monthly = params[:monthly].present?
    if @monthly
      @recurring_donation = @event.recurring_donations.build(
        name: params[:name],
        email: params[:email],
        amount: params[:amount],
        message: params[:message],
        fee_covered: params[:fee_covered],
        tax_deductible:
      )
    end

    @placeholder_amount = "%.2f" % (DonationService::SuggestedAmount.new(@event, monthly: @monthly).run / 100.0)
  end
end
