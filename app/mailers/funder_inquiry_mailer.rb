# frozen_string_literal: true

# Sent when a funder submits the inquiry form on the /for/funders landing page.
# It's a warm confirmation addressed to the funder, with the HCB operations team CC'd
# so a real person can follow up on the same thread.
class FunderInquiryMailer < ApplicationMailer
  # Team members CC'd on funder inquiries so they can follow up directly.
  # Referenced by public_id so the list survives email changes; any id that
  # no longer resolves to a user is silently skipped.
  CC_USER_IDS = [
    "usr_wVtRav", # Melanie
    "usr_notLKl", # Paul
    "usr_8YEt6d", # Gary
  ].freeze

  def inquiry
    @name = params[:name].presence
    @email = params[:email]
    @message = params[:message].presence

    team_cc = CC_USER_IDS.filter_map do |id|
      User.find_by_public_id(id)&.email_address_with_name(full_name: true)
    end

    mail(
      to: @email,
      cc: [ApplicationMailer::OPERATIONS_EMAIL, *team_cc],
      subject: "Thanks for reaching out to HCB"
    )
  end

end
