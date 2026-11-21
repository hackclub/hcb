# frozen_string_literal: true

class AiSafetyInquiryMailerPreview < ActionMailer::Preview
  def confirmation
    AiSafetyInquiryMailer.with(**inquiry).confirmation
  end

  def notify_team
    AiSafetyInquiryMailer.with(**inquiry).notify_team
  end

  private

  def inquiry
    {
      name: "Ada Park",
      email: "ada@example.org",
      audience: "team",
      message: "Our funder approved a $400,000 grant. We're three researchers in Berkeley and London, starting in January.",
      ref: "newsletter"
    }
  end

end
