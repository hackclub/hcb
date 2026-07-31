# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Paging engineers from admin", type: :request do
  let(:enqueue_url) { "https://events.pagerduty.com/v2/enqueue" }
  let(:routing_key) { "R0UT1NGK3Y" }
  let(:valid_params) { { message: "Transfers are failing for every org", confirmation: "PAGE" } }

  def sign_in(user)
    session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)
  end

  def stub_pager_duty(status: 202, body: nil, content_type: "application/json")
    body ||= { status: "success", dedup_key: "abc123" }.to_json
    stub_request(:post, enqueue_url).to_return(status:, body:, headers: { "Content-Type" => content_type })
  end

  before do
    allow(PagerDutyService).to receive(:manual_page_routing_key).and_return(routing_key)
    stub_pager_duty
  end

  describe "authorization" do
    it "turns away a signed-out visitor without paging anyone" do
      post admin_page_engineers_path, params: valid_params

      expect(response).to redirect_to(/\/users\/auth/)
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "turns away a regular user without paging anyone" do
      sign_in(create(:user))

      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "turns away an auditor without paging anyone" do
      sign_in(create(:user, :make_auditor))

      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "sends an auditor somewhere useful instead of a sign-in screen they're already past" do
      sign_in(create(:user, :make_auditor))

      get admin_page_engineers_path

      expect(response).to redirect_to(admin_tools_path)
      expect(flash[:error]).to include("Only admins can page")
    end

    it "blocks an auditor from the form itself" do
      sign_in(create(:user, :make_auditor))

      get admin_page_engineers_path

      expect(response).not_to have_http_status(:ok)
    end

    it "lets an admin reach the form" do
      sign_in(create(:user, :make_admin))

      get admin_page_engineers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Type PAGE to confirm")
    end
  end

  describe "paging" do
    let(:admin) { create(:user, :make_admin, full_name: "Jane Admin") }

    before { sign_in(admin) }

    it "opens a critical incident with the message and who sent it" do
      post admin_page_engineers_path, params: valid_params

      expect(response).to redirect_to(admin_tools_path)
      expect(flash[:success]).to include("PagerDuty accepted the page")
      expect(a_request(:post, enqueue_url).with { |req|
        body = JSON.parse(req.body)
        payload = body["payload"]
        body["routing_key"] == routing_key &&
          body["event_action"] == "trigger" &&
          payload["severity"] == "critical" &&
          payload["summary"].include?("Transfers are failing for every org") &&
          payload["summary"].include?("Jane Admin") &&
          payload["custom_details"]["paged_by_email"] == admin.email
      }).to have_been_made.once
    end

    it "sets the routing fields PagerDuty event rules key off" do
      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url).with { |req|
        payload = JSON.parse(req.body)["payload"]
        payload["component"] == "hcb" &&
          payload["group"] == "manual" &&
          payload["class"] == "manual_page" &&
          JSON.parse(req.body)["client"] == "HCB"
      }).to have_been_made
    end

    it "surfaces the PagerDuty reference so the admin can follow up" do
      post admin_page_engineers_path, params: valid_params

      expect(flash[:success]).to include("abc123")
    end

    it "leads the summary with the message so it survives notification truncation" do
      captured = nil
      stub_request(:post, enqueue_url).to_return do |request|
        captured = JSON.parse(request.body)
        { status: 202, body: { status: "success", dedup_key: "abc123" }.to_json, headers: { "Content-Type" => "application/json" } }
      end

      post admin_page_engineers_path, params: valid_params

      summary = captured.dig("payload", "summary")
      expect(summary).to include("Transfers are failing for every org")
      expect(summary).to include("Jane Admin")
      expect(summary.index("Transfers are failing")).to be < summary.index("Jane Admin")
    end

    it "marks the environment when it isn't production, so staging can't look like an outage" do
      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url).with { |req|
        JSON.parse(req.body)["payload"]["summary"].start_with?("[test]")
      }).to have_been_made
    end

    it "links back to the person who paged" do
      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url).with { |req|
        link = JSON.parse(req.body)["links"].first
        link["href"] == Rails.application.routes.url_helpers.user_url(admin, host: "www.example.com") &&
          link["text"].include?("Jane Admin")
      }).to have_been_made
    end

    it "accepts a message exactly at the length limit" do
      post admin_page_engineers_path, params: valid_params.merge(message: "a" * Admin::EngineeringPagesController::MAX_MESSAGE_LENGTH)

      expect(a_request(:post, enqueue_url)).to have_been_made
    end
  end

  describe "attributing an impersonated page" do
    it "records the real actor so on-call doesn't call back the impersonated user" do
      real_admin = create(:user, :make_admin, full_name: "Real Admin")
      target = create(:user, :make_admin, full_name: "Target Admin")
      session = create(:user_session, user: target, impersonated_by: real_admin, verified: true, expiration_at: 1.hour.from_now)
      allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(session)

      post admin_page_engineers_path, params: valid_params

      expect(a_request(:post, enqueue_url).with { |req|
        JSON.parse(req.body)["payload"]["custom_details"]["impersonated_by"] == real_admin.email
      }).to have_been_made
    end
  end

  describe "refusing to page" do
    before { sign_in(create(:user, :make_admin)) }

    it "rejects a blank message" do
      post admin_page_engineers_path, params: valid_params.merge(message: "   ")

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to include("what's happening")
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "rejects a message too long to fit in a phone notification" do
      post admin_page_engineers_path, params: valid_params.merge(message: "a" * 200)

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to include("characters")
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "keeps the typed message on the form so it isn't lost" do
      post admin_page_engineers_path, params: valid_params.merge(message: "a" * 200)

      expect(response.body).to include("a" * 200)
    end

    it "refuses without the typed confirmation, even though the check is also client-side" do
      post admin_page_engineers_path, params: { message: "everything is down" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "refuses a confirmation with the wrong casing" do
      post admin_page_engineers_path, params: valid_params.merge(confirmation: "page")

      expect(response).to have_http_status(:unprocessable_content)
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "refuses when PagerDuty isn't configured" do
      allow(PagerDutyService).to receive(:manual_page_routing_key).and_return(nil)

      post admin_page_engineers_path, params: valid_params

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to include("isn't configured")
      expect(a_request(:post, enqueue_url)).not_to have_been_made
    end

    it "hides the form entirely when PagerDuty isn't configured" do
      allow(PagerDutyService).to receive(:manual_page_routing_key).and_return(nil)

      get admin_page_engineers_path

      expect(response.body).not_to include("Type PAGE to confirm")
      expect(response.body).to include("isn’t configured in this environment")
    end
  end

  # The one invariant that matters: an admin must never be told a human was
  # reached when they weren't.
  describe "never reporting a false success" do
    before { sign_in(create(:user, :make_admin)) }

    {
      "PagerDuty returns a server error"               => { status: 500, body: "{}" },
      "PagerDuty rate limits us"                       => { status: 429, body: "{}" },
      "an intercepting proxy answers 200"              => { status: 200, body: "<html>proxy</html>", content_type: "text/html" },
      "the response is an empty 204"                   => { status: 204, body: "" },
      "a 301 redirect is never followed"               => { status: 301, body: "" },
      "PagerDuty accepts but reports an invalid event" => { status: 202, body: { status: "invalid event", errors: ["Routing key not found"] }.to_json },
    }.each do |description, response_attrs|
      it "reports failure when #{description}" do
        stub_pager_duty(**response_attrs)

        post admin_page_engineers_path, params: valid_params

        expect(flash[:success]).to be_nil
        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to include("Contact an engineer directly")
      end
    end

    it "reports failure when the connection is refused" do
      stub_request(:post, enqueue_url).to_raise(Errno::ECONNREFUSED)

      post admin_page_engineers_path, params: valid_params

      expect(flash[:success]).to be_nil
      expect(response).to have_http_status(:bad_gateway)
    end

    # Never connected, so the event definitively did not reach PagerDuty.
    # faraday-net_http maps Net::OpenTimeout to Faraday::ConnectionFailed.
    it "states plainly that nobody was paged when the connection never opened" do
      stub_request(:post, enqueue_url).to_timeout

      post admin_page_engineers_path, params: valid_params

      expect(flash[:success]).to be_nil
      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to include("nobody was notified")
    end

    # The request went out but no response came back, so PagerDuty may well
    # have enqueued it. Claiming nobody was paged would send the admin off to
    # wake a second person for nothing.
    it "says the outcome is unknown when the response times out" do
      stub_request(:post, enqueue_url).to_raise(Faraday::TimeoutError)

      post admin_page_engineers_path, params: valid_params

      expect(flash[:success]).to be_nil
      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to include("may have fired anyway")
      expect(response.body).not_to include("nobody was notified")
    end
  end
end
