# frozen_string_literal: true

require "rails_helper"

# POST /for/ai-safety/inquiry: stores the lead, emails the submitter and the team, and
# never 500s on hostile input.
RSpec::Matchers.define_negated_matcher :not_change, :change
RSpec::Matchers.define_negated_matcher :not_have_enqueued_mail, :have_enqueued_mail

RSpec.describe "AI safety inquiry form", type: :request do
  let(:valid_params) do
    {
      ai_safety_inquiry: {
        name: "Ada Park", email: "ada@example.org", audience: "funder",
        message: "A $400,000 grant, starting in January.", ref: "Newsletter_1"
      }
    }
  end

  def page
    Nokogiri::HTML(response.body)
  end

  it "stores the inquiry, enqueues both emails, and shows the confirmation once" do
    expect { post ai_safety_inquiry_path, params: valid_params }
      .to change(MarketingInquiry, :count).by(1)
      .and have_enqueued_mail(AiSafetyInquiryMailer, :confirmation)
      .and have_enqueued_mail(AiSafetyInquiryMailer, :notify_team)

    inquiry = MarketingInquiry.last
    expect(inquiry).to have_attributes(page: "ai_safety", audience: "funder", ref: "newsletter_1", email: "ada@example.org")
    expect(response).to redirect_to(ai_safety_path(anchor: "talk-to-us"))

    follow_redirect!
    status = page.at_css("#talk-to-us [role=status]").text
    expect(status).to include("Got it.")
    expect(status).not_to include("grant letter")
    expect(page.at_css("#talk-to-us form")).to be_nil

    # The confirmation rides on flash, so a reload shows the form again.
    get ai_safety_path
    expect(page.at_css("#talk-to-us form")).to be_present
  end

  it "drops an audience or ref outside the allowlist" do
    post ai_safety_inquiry_path, params: { ai_safety_inquiry: valid_params[:ai_safety_inquiry].merge(audience: "admin", ref: "<script>") }

    expect(MarketingInquiry.last).to have_attributes(audience: nil, ref: nil)
  end

  # Flash comes back with String keys after the cookie round trip; every field must prefill.
  it "rejects an invalid email, stores nothing, and prefills every field" do
    params = { ai_safety_inquiry: valid_params[:ai_safety_inquiry].merge(email: "not-an-email") }

    expect do
      post ai_safety_inquiry_path, params:
    end.not_to change(MarketingInquiry, :count)

    follow_redirect!
    expect(page.at_css("[role=alert]").text).to include("Please enter a valid email address.")
    expect(page.at_css("#ai_safety_inquiry_name")["value"]).to eq("Ada Park")
    expect(page.at_css("#ai_safety_inquiry_email")["value"]).to eq("not-an-email")
    expect(page.at_css("#ai_safety_inquiry_message").text.strip).to eq("A $400,000 grant, starting in January.")
    expect(page.css("input[name='ai_safety_inquiry[audience]'][checked]").map { |i| i["value"] }).to eq(["funder"])
    expect(page.at_css("input[name='ai_safety_inquiry[ref]']")["value"]).to eq("newsletter_1")
  end

  # The whole message in the flash would overflow the 4 KB session cookie.
  it "redirects, not 500s, on a long message with a bad email" do
    post ai_safety_inquiry_path, params: { ai_safety_inquiry: { email: "bad", message: "x" * 3_000 } }

    expect(response).to have_http_status(:found)
  end

  it "does not 500 on a scalar where the nested params should be" do
    post ai_safety_inquiry_path, params: { ai_safety_inquiry: "oops" }

    expect(response).to have_http_status(:found)
  end

  it "drops bot submissions that fill the honeypot" do
    expect do
      post ai_safety_inquiry_path, params: valid_params.merge(subtitle: "i am a bot")
    end.to not_change(MarketingInquiry, :count)
      .and not_have_enqueued_mail(AiSafetyInquiryMailer, :confirmation)

    expect(response).to have_http_status(:ok)
  end

  # The app default (null_session) would still run the action on a bad token.
  it "refuses a cross-site post without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    expect do
      post ai_safety_inquiry_path, params: valid_params
    end.not_to change(MarketingInquiry, :count)
    expect(response).to redirect_to(ai_safety_path(anchor: "talk-to-us"))
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  describe "GET /ai-safety" do
    it "redirects to the page, keeping known params" do
      get "/ai-safety?ref=x"

      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to end_with("/for/ai-safety?ref=x")
    end

    it "does not 500 on a malformed query" do
      get "/ai-safety?x=%7B"

      expect(response).to have_http_status(:moved_permanently)
    end
  end
end
