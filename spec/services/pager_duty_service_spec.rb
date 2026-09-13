# frozen_string_literal: true

require "rails_helper"

RSpec.describe PagerDutyService do
  let(:enqueue_url) { "https://events.pagerduty.com/v2/enqueue" }

  def accepted_body
    { status: "success", message: "Event processed", dedup_key: "abc123" }.to_json
  end

  def stub_pager_duty(status: 202, body: accepted_body, content_type: "application/json")
    stub_request(:post, enqueue_url).to_return(
      status:, body:, headers: { "Content-Type" => content_type }
    )
  end

  describe ".manual_page_routing_key" do
    it "reads the PAGERDUTY__MANUAL_PAGE_ROUTING_KEY environment variable" do
      # Guards the credential key itself: a typo in either segment would
      # disable paging in production with no other signal, because
      # Credentials.fetch returns nil rather than raising.
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PAGERDUTY__MANUAL_PAGE_ROUTING_KEY").and_return("from-env")

      expect(described_class.manual_page_routing_key).to eq("from-env")
    end
  end

  describe ".manual_page_enabled?" do
    it "is false when the routing key is unset" do
      allow(described_class).to receive(:manual_page_routing_key).and_return(nil)

      expect(described_class.manual_page_enabled?).to be false
    end

    it "is true when the routing key is present" do
      allow(described_class).to receive(:manual_page_routing_key).and_return("R0UT1NGK3Y")

      expect(described_class.manual_page_enabled?).to be true
    end
  end

  describe ".trigger" do
    it "posts a trigger event to the Events API" do
      stub_pager_duty

      response = described_class.trigger(
        routing_key: "R0UT1NGK3Y",
        summary: "Everything is on fire",
        source: "hcb.hackclub.com",
        custom_details: { paged_by: "Jane" }
      )

      expect(response["dedup_key"]).to eq("abc123")
      expect(a_request(:post, enqueue_url).with { |req|
        body = JSON.parse(req.body)
        body["routing_key"] == "R0UT1NGK3Y" &&
          body["event_action"] == "trigger" &&
          body["payload"]["summary"] == "Everything is on fire" &&
          body["payload"]["severity"] == "critical" &&
          body["payload"]["source"] == "hcb.hackclub.com" &&
          body["payload"]["custom_details"] == { "paged_by" => "Jane" }
      }).to have_been_requested
    end

    it "omits a dedup_key so PagerDuty won't collapse a second page into the first" do
      stub_pager_duty

      described_class.trigger(routing_key: "key", summary: "hi", source: "hcb")

      expect(a_request(:post, enqueue_url).with { |req| !JSON.parse(req.body).key?("dedup_key") }).to have_been_requested
    end

    it "truncates a long summary while keeping the start of the message" do
      stub_pager_duty

      described_class.trigger(routing_key: "key", summary: "start #{"a" * 2000}", source: "hcb")

      expect(a_request(:post, enqueue_url).with { |req|
        summary = JSON.parse(req.body)["payload"]["summary"]
        summary.length <= described_class::MAX_SUMMARY_LENGTH && summary.start_with?("start ")
      }).to have_been_requested
    end

    it "rejects a severity PagerDuty doesn't understand" do
      expect {
        described_class.trigger(routing_key: "key", summary: "hi", source: "hcb", severity: "catastrophic")
      }.to raise_error(ArgumentError, /unknown severity/)
    end

    describe "responses that must not be mistaken for a successful page" do
      # Faraday's raise_error middleware only covers 4xx and 5xx, so each of
      # these would otherwise return normally and read as "someone was paged".
      {
        "a 200 from an intercepting proxy"       => { status: 200, body: "<html>proxy</html>", content_type: "text/html" },
        "an empty 204"                           => { status: 204, body: "" },
        "a 301 redirect that was never followed" => { status: 301, body: "" },
        "a 202 carrying an error body"           => { status: 202, body: { status: "invalid event", errors: ["Routing key not found"] }.to_json },
        "a 202 with no dedup_key"                => { status: 202, body: { status: "success" }.to_json },
      }.each do |description, response|
        it "raises on #{description}" do
          stub_pager_duty(**response)

          expect {
            described_class.trigger(routing_key: "key", summary: "hi", source: "hcb")
          }.to raise_error(PagerDutyService::EventRejected)
        end
      end
    end

    it "raises when PagerDuty rejects the event outright" do
      stub_pager_duty(status: 400, body: "{}")

      expect {
        described_class.trigger(routing_key: "key", summary: "hi", source: "hcb")
      }.to raise_error(Faraday::BadRequestError)
    end

    it "raises when PagerDuty rate limits us" do
      stub_pager_duty(status: 429, body: "{}")

      expect {
        described_class.trigger(routing_key: "key", summary: "hi", source: "hcb")
      }.to raise_error(Faraday::Error)
    end

    it "attaches the response body to AppSignal as custom data, which tags can't hold" do
      stub_pager_duty(status: 400, body: { errors: ["Event object is invalid"] }.to_json)
      allow(Appsignal).to receive(:add_tags)
      expect(Appsignal).to receive(:add_custom_data).with(
        hash_including(pager_duty: hash_including(response_status: 400))
      )

      expect {
        described_class.trigger(routing_key: "key", summary: "hi", source: "hcb")
      }.to raise_error(Faraday::BadRequestError)
    end
  end
end
