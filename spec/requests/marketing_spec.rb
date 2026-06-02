# frozen_string_literal: true

require "rails_helper"

# The /for/funders marketing landing page. Public, server-rendered, and largely static;
# the only dynamic behavior is the funder inquiry form, which emails the ops team. The
# whole page is gated behind the :funders_landing_page Flipper flag during rollout.
RSpec.describe "Funders landing page", type: :request do
  # Happy-path examples assume the rollout flag is on; the gating example turns it off.
  before { Flipper.enable(MarketingController::FUNDERS_FLAG) }

  describe "GET /for/funders" do
    it "renders for signed-out visitors when the flag is enabled" do
      get funders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deploy your capital as grants")
    end

    it "shows the signed-out nav (Log in / Talk to our team), not a dashboard link" do
      get funders_path

      expect(response.body).to include("Log in")
      expect(response.body).to include("Talk to our team")
      expect(response.body).not_to include(">Dashboard<")
    end

    it "is indexable (does not set a noindex X-Robots-Tag)" do
      get funders_path

      expect(response.headers["X-Robots-Tag"]).to be_blank
    end

    it "shows a dashboard link for signed-in users instead of login" do
      user = create(:user, verified: true)
      session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)

      get funders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dashboard")
      expect(response.body).not_to include(">Log in<")
    end

    it "404s when the funders flag is disabled" do
      Flipper.disable(MarketingController::FUNDERS_FLAG)

      get funders_path

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Deploy your capital as grants")
    end
  end

  describe "POST /for/funders/inquiry" do
    it "emails the funder a confirmation and CCs the ops team, then redirects" do
      perform_enqueued_jobs do
        post funder_inquiry_path, params: { email: "funder@example.com", name: "Ada Lovelace", message: "Interested in regranting." }
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail).to be_present
      expect(mail.to).to include("funder@example.com")
      expect(mail.cc).to include(ApplicationMailer::OPERATIONS_EMAIL)
      expect(response).to redirect_to(funders_path(anchor: "talk-to-us"))
      expect(flash[:funder_inquiry]).to eq("received")
    end

    it "rejects an invalid email without sending mail" do
      expect do
        post funder_inquiry_path, params: { email: "not-an-email" }
      end.not_to have_enqueued_mail(FunderInquiryMailer, :inquiry)

      expect(response).to redirect_to(funders_path(anchor: "talk-to-us"))
    end

    it "drops bot submissions that fill the invisible_captcha honeypot" do
      expect do
        post funder_inquiry_path, params: { email: "bot@example.com", subtitle: "i am a bot" }
      end.not_to have_enqueued_mail(FunderInquiryMailer, :inquiry)
    end

    it "404s when the funders flag is disabled" do
      Flipper.disable(MarketingController::FUNDERS_FLAG)

      post funder_inquiry_path, params: { email: "funder@example.com" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
