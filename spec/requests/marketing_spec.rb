# frozen_string_literal: true

require "rails_helper"

# The /for/funders marketing landing page.
#
# Intent/context that isn't obvious from the code or copy:
# - It lives outside the authenticated app shell: it skips the global sign-in requirement
#   and Pundit authorization, and renders with the lightweight "marketing" layout. It's
#   light-mode only — the funder audience doesn't need dark mode, so it's deferred.
# - Unlike the rest of the app (which sends a noindex X-Robots-Tag), this page is
#   *deliberately* indexable — it's public marketing meant to be found in search.
# - During rollout the whole page sits behind :funders_landing_page. Visitors without the
#   flag get a 404 (not a 403/redirect) so the unreleased page is indistinguishable from one
#   that doesn't exist.
# - "HCB by Hack Club": Hack Club (legally The Hack Foundation) is the 501(c)(3); HCB is the
#   platform it operates. The page never claims HCB itself is the charity.
RSpec.describe "Funders landing page", type: :request do
  # Most examples assume the rollout flag is on; the gating examples flip it off explicitly.
  before { Flipper.enable(MarketingController::FUNDERS_FLAG) }

  describe "GET /for/funders" do
    it "renders for signed-out visitors when the flag is enabled" do
      get funders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deploy your capital as grants")
    end

    # The final CTA renders the *detailed* inquiry form (name + message), not the compact
    # email-only one — guards `detailed: true` on the render, which has been dropped twice by
    # copy-edit PRs touching that section.
    it "renders the detailed inquiry form with name and message fields" do
      get funders_path

      expect(response.body).to include('name="name"')
      expect(response.body).to include('name="message"')
    end

    # Signed-out funders are funnelled to "Talk to our team" (which scrolls to the inquiry
    # form), NOT to signup — we want a conversation first, not a self-serve account.
    it "shows the signed-out nav (Log in / Talk to our team), not a dashboard link" do
      get funders_path

      expect(response.body).to include("Log in")
      expect(response.body).to include("Talk to our team")
      expect(response.body).not_to include(">Dashboard<")
    end

    # The rest of the app is noindex; this page opts back in (an after_action strips the
    # X-Robots-Tag) so search engines can surface it.
    it "is indexable (does not set a noindex X-Robots-Tag)" do
      get funders_path

      expect(response.headers["X-Robots-Tag"]).to be_blank
    end

    # Already-authenticated visitors get a direct path back to their dashboard instead of the
    # signed-out login link.
    it "shows a dashboard link for signed-in users instead of login" do
      user = create(:user, verified: true)
      session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)

      get funders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dashboard")
      expect(response.body).not_to include(">Log in<")
    end

    # Before launch the page must be invisible to the public — a 404 (not a redirect or 403)
    # so its existence isn't leaked.
    it "404s when the funders flag is disabled" do
      Flipper.disable(MarketingController::FUNDERS_FLAG)

      get funders_path

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Deploy your capital as grants")
    end
  end

  # The "Funders on HCB" testimonials block has its OWN flag, separate from the page flag.
  # The Mitchell Hashimoto quote is adapted from public material and still pending sign-off —
  # so the page can ship publicly while this section stays hidden until the quote is approved,
  # then it's flipped on without a deploy. (The Argosy story lives in its own ungated section.)
  describe "Funders on HCB testimonials section" do
    it "is hidden by default so the page can launch before the quotes are approved" do
      get funders_path

      expect(response.body).not_to include("Funders on HCB")
    end

    it "appears once the testimonials flag is enabled" do
      Flipper.enable(MarketingController::TESTIMONIALS_FLAG)

      get funders_path

      expect(response.body).to include("Funders on HCB")
      expect(response.body).to include("Mitchell Hashimoto")
    end
  end

  # The "Where it lands" Ghostty tile is always shown.
  describe "Ghostty content" do
    it "shows the Ghostty tile" do
      get funders_path

      expect(response.body).to include("ghostty.org")
      expect(response.body).to include("Ghostty")
    end
  end

  # The Argosy Foundation case study is gated separately so it can be held back until cleared.
  describe "Argosy case study" do
    it "is hidden by default" do
      get funders_path

      expect(response.body).not_to include("Case study")
    end

    it "appears once :funders_landing_argosy is enabled" do
      Flipper.enable(MarketingController::ARGOSY_FLAG)

      get funders_path

      expect(response.body).to include("Case study")
      expect(response.body).to include("Argosy Foundation")
    end
  end

  describe "POST /for/funders/inquiry" do
    # A lead is precious: we email the funder a confirmation AND CC the ops team, so an
    # inquiry can't be silently lost even if one delivery path fails.
    it "emails the funder a confirmation and CCs the ops team, then redirects" do
      perform_enqueued_jobs do
        post funder_inquiry_path, params: { email: "funder@example.com", name: "Ada Lovelace", message: "Interested in regranting." }
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail).to be_present
      expect(mail.to).to include("funder@example.com")
      expect(mail.cc).to include(ApplicationMailer::OPERATIONS_EMAIL)
      # The confirmation rides on flash, not a query param: a shared or bookmarked
      # "?inquiry=received" URL would otherwise show the "Thanks" card to whoever opens it.
      expect(response).to redirect_to(funders_path(anchor: "talk-to-us"))
      expect(flash[:funder_inquiry]).to eq("received")
    end

    # On a validation error we carry the typed values back via flash so the funder isn't
    # forced to retype everything — the form repopulates from flash[:funder_form].
    it "rejects an invalid email without sending mail, and carries the values back for prefill" do
      expect do
        post funder_inquiry_path, params: { email: "not-an-email", name: "Ada", message: "Hi" }
      end.not_to have_enqueued_mail(FunderInquiryMailer, :inquiry)

      expect(response).to redirect_to(funders_path(anchor: "talk-to-us"))
      expect(flash[:error]).to be_present
      expect(flash[:funder_form]).to include("email" => "not-an-email", "name" => "Ada", "message" => "Hi")
    end

    # Anti-bot via the invisible_captcha honeypot: :subtitle is hidden from humans, so any
    # value in it marks a bot and the submission is dropped before mail is enqueued.
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
