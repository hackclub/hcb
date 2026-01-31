# frozen_string_literal: true

module DonationPageSetup
  extend ActiveSupport::Concern

  def build_donation_page!(event:, params:, request:)
    unless event.donation_page_available?
      return not_found
    end

    # Handle tier lookup if tier_id is present
    if params[:tier_id].present?
      @tier = event.donation_tiers.find_by(id: params[:tier_id]) unless params[:tier_id] == "custom"

      if @tier.nil? && params[:tier_id] != "custom"
        redirect_to start_donation_donations_path(event), flash: { error: "Donation tier could not be found." }
        return false
      end
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

    @monthly = params[:monthly].present? || params[:tier_id].present?
    @skip_layout_og_tags = true
    
    if @monthly
      @recurring_donation = event.recurring_donations.build(
        name: params[:name],
        email: params[:email],
        amount: params[:amount],
        message: params[:message],
        fee_covered: params[:fee_covered],
        tax_deductible:
      )
    end

    @placeholder_amount = "%.2f" % (DonationService::SuggestedAmount.new(event, monthly: @monthly).run / 100.0)

    true
  end
end
