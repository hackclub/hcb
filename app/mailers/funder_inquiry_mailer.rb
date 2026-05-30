# frozen_string_literal: true

# Sent when a funder submits the inquiry form on the /for/funders landing page.
# It's a warm confirmation addressed to the funder, with the HCB operations team CC'd
# so a real person can follow up on the same thread.
class FunderInquiryMailer < ApplicationMailer
  def inquiry
    @name = params[:name].presence
    @email = params[:email]
    @message = params[:message].presence

    mail(
      to: @email,
      cc: ApplicationMailer::OPERATIONS_EMAIL,
      subject: "Thanks for reaching out to HCB"
    )
  end

end
