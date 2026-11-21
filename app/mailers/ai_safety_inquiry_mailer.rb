# frozen_string_literal: true

# Sent when someone submits the inquiry form on /for/ai-safety: a confirmation to the
# submitter and a notification to the team inbox. Takes plain strings only.
class AiSafetyInquiryMailer < ApplicationMailer
  TEAM_EMAIL = "aisafety@hackclub.com"

  before_action :set_inquiry

  # The default footer prints a phone number and student-focused copy.
  def confirmation
    @first_name = @name.split.first if @name.present? && @name.split.first.length <= 40 && !@name.match?(MarketingInquiry::LINKISH)
    @message = nil if @message&.match?(MarketingInquiry::LINKISH)
    @message = @message&.first(1_000)

    mail(to: @email, reply_to: TEAM_EMAIL, subject: "Thanks for reaching out to HCB") do |format|
      format.html { render layout: "mailer/no_footer" }
    end
  end

  def notify_team
    @audience_label = MarketingInquiry::AUDIENCES.fetch(@audience, "No answer")
    @page_url = ai_safety_url

    mail(
      to: TEAM_EMAIL,
      reply_to: email_address_with_name(@email, @name.to_s),
      subject: "AI safety inquiry: #{@audience_label} from #{(@name.presence || @email).first(80)}"
    )
  end

  private

  def set_inquiry
    # Headers can't carry control characters, and the controller isn't the only caller.
    @name = params[:name].to_s.gsub(/[[:cntrl:]]/, " ").squish.presence
    @email = params[:email].to_s.gsub(/[[:cntrl:]]/, "").strip
    @audience = params[:audience]
    @message = params[:message].to_s.strip.presence
    @ref = params[:ref].presence
  end

end
