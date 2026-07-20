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
# - "HCB by Hack Club": Hack Club (legally The Hack Foundation) is the 501(c)(3); HCB is the
#   platform it operates. The page never claims HCB itself is the charity.
RSpec.describe "Funders landing page", type: :request do
  describe "GET /for/funders" do
    it "renders for signed-out visitors" do
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
  end

  # The "Funders on HCB" testimonials block is gated behind its own flag. The Mitchell
  # Hashimoto quote is adapted from public material and still pending sign-off — so the page
  # stays public while this section is hidden until the quote is approved, then it's flipped
  # on without a deploy. (The Argosy story now ships ungated in its own section.)
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

  describe "Argosy case study" do
    it "shows the Argosy Foundation case study" do
      get funders_path

      expect(response.body).to include("Case study")
      expect(response.body).to include("Argosy Foundation")
    end
  end

  # The HCB vs. private-foundation vs. DAF comparison table. Its detail rows ship EXPANDED
  # in the server HTML and are collapsed by the funders-compare Stimulus controller, so the
  # evidence-rich copy and IRS sources are present for AI crawlers and no-JS visitors (this
  # page is deliberately indexable). AI crawlers don't run JS, so any content that only
  # appeared after client-side rendering would be invisible to them.
  describe "comparison table" do
    before { Flipper.enable(MarketingController::COMPARISON_FAQ_FLAG) }

    it "renders the funder-facing comparison rows" do
      get funders_path

      expect(response.body).to include("Practical minimum to be worth it")
      expect(response.body).to include("Back office")
      expect(response.body).to include("Mandatory annual payout")
      expect(response.body).to include("Layered fees")
    end

    # The AI-SEO premise: the detail copy and cited sources must be in the raw HTML, and
    # expanded by default — the controller collapses them only once JS is running.
    it "server-renders the expandable detail copy and IRS sources, expanded by default" do
      get funders_path

      expect(response.body).to include("expenditure responsibility")
      expect(response.body).to include("1.39% excise tax on net investment income")
      expect(response.body).to include("irs.gov")
      expect(response.body).to include('aria-expanded="true"')
    end

    # Answer-first interceptor line that doubles as a citable passage for AI engines.
    it "shows the answer-first interceptor caption" do
      get funders_path

      expect(response.body).to include("Fund a charitable project tax-deductibly from day one")
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
  end

  # The short "Common questions" teaser on the main page links to the dedicated FAQ subpage.
  describe "FAQ teaser on the funders page" do
    before { Flipper.enable(MarketingController::COMPARISON_FAQ_FLAG) }

    it "shows the common-questions teaser and a link to the full FAQ" do
      get funders_path

      expect(response.body).to include("Common questions")
      expect(response.body).to include("How is HCB different from a donor-advised fund?")
      expect(response.body).to include(funders_faq_path)
    end
  end

  # The dedicated funder FAQ subpage: fully server-rendered, grouped Q&A with FAQPage structured
  # data, and deliberately indexable like the main funders page.
  describe "GET /for/funders/faq" do
    before { Flipper.enable(MarketingController::COMPARISON_FAQ_FLAG) }

    it "renders grouped questions and answers, server-side" do
      get funders_faq_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Funder questions, answered")
      expect(response.body).to include("How do I accept tax-deductible donations for a project that isn't a 501(c)(3)?")
      expect(response.body).to include("Through fiscal sponsorship.")
      expect(response.body).to include("Tax and deductibility") # a topic heading
    end

    it "emits FAQPage structured data covering the questions" do
      get funders_faq_path

      expect(response.body).to include('"@type":"FAQPage"')
      expect(response.body).to include("Do donor-advised funds have a payout requirement?")
    end

    it "is indexable (does not set a noindex X-Robots-Tag)" do
      get funders_faq_path

      expect(response.headers["X-Robots-Tag"]).to be_blank
    end

    it "cross-links related questions to their stable id anchor" do
      get funders_faq_path

      expect(response.body).to include('class="mk-meta__link"')
      expect(response.body).to include('href="#fiscal-sponsorship"')
      expect(response.body).to include('id="fiscal-sponsorship"') # the link target exists
    end
  end

  # The funders_landing_comparison_faq flag gates all of the above: with it off, the page falls
  # back to the original static comparison table, the FAQ teaser is hidden, and the subpage 404s.
  describe "with the funders_landing_comparison_faq flag off" do
    before { Flipper.disable(MarketingController::COMPARISON_FAQ_FLAG) }

    it "falls back to the original static comparison table and hides the FAQ teaser" do
      get funders_path

      expect(response.body).to include("Fund brand-new initiatives") # original row label
      expect(response.body).not_to include("Practical minimum to be worth it") # new table only
      expect(response.body).not_to include("Common questions") # FAQ teaser hidden
    end

    it "404s the FAQ subpage" do
      get funders_faq_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
