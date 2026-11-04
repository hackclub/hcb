# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CSP Violation Reports", type: :request do
  let(:max_bytes) { CspViolationReportsController::MAX_BODY_BYTES }
  # Bytes the JSON envelope adds around an empty "blocked-uri" value.
  let(:envelope) { { "blocked-uri" => "" }.to_json.bytesize }

  let(:report) do
    {
      "csp-report" => {
        "document-uri"       => "https://hcb.hackclub.com/donations/start/hq",
        "violated-directive" => "script-src",
        "blocked-uri"        => "https://evil.example/x.js",
      }
    }.to_json
  end

  def post_report(body, content_type: "application/csp-report")
    post Rails.configuration.constants[:csp_violation_report_path], params: body, headers: { "Content-Type" => content_type }
  end

  it "accepts an unauthenticated report and logs it" do
    allow(Rails.logger).to receive(:warn).and_call_original

    post_report(report)

    expect(Rails.logger).to have_received(:warn).with(/\[csp-violation\].*evil\.example/)
    expect(response).to have_http_status(:no_content)
  end

  # Safari has sent reports as application/json rather than application/csp-report.
  it "accepts a report sent as application/json" do
    post_report(report, content_type: "application/json")

    expect(response).to have_http_status(:no_content)
  end

  it "accepts a report that is not wrapped in csp-report" do
    allow(Rails.logger).to receive(:warn).and_call_original

    post_report({ "violated-directive" => "script-src" }.to_json)

    expect(Rails.logger).to have_received(:warn).with(/script-src/)
    expect(response).to have_http_status(:no_content)
  end

  it "truncates attacker-controlled fields before logging" do
    allow(Rails.logger).to receive(:warn).and_call_original

    post_report({ "blocked-uri" => "https://evil.example/#{'a' * 2_000}" }.to_json)

    expect(Rails.logger).to have_received(:warn) do |line|
      expect(line.length).to be < CspViolationReportsController::MAX_FIELD_CHARS + 200
    end
  end

  it "logs a repeated violation once per window, not once per page load" do
    allow(Rails.logger).to receive(:warn).and_call_original
    allow(Rails.cache).to receive(:write).and_return(true, false)

    2.times { post_report(report) }

    expect(Rails.logger).to have_received(:warn).with(/csp-violation/).once
  end

  # JSON.parse does not validate UTF-8, so this reached String#presence and 500'd.
  it "survives invalid UTF-8 in a report field" do
    body = %({"csp-report":{"blocked-uri":"https://evil.example/\xC3\x28\xFF"}}).dup.force_encoding("BINARY")

    post_report(body)

    expect(response).to have_http_status(:no_content)
  end

  it "rejects a body that is not JSON" do
    post_report("not json")

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects an empty body" do
    post_report("")

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects JSON that isn't an object" do
    ["[]", "null", '"nope"'].each do |body|
      post_report(body)

      expect(response).to have_http_status(:bad_request), "expected #{body} to be rejected"
    end
  end

  # Indexing a non-Hash with a String raises, so this would 500 without the guard.
  it "rejects a report whose csp-report value is not an object" do
    [["x"], 5, true].each do |value|
      post_report({ "csp-report" => value }.to_json)

      expect(response).to have_http_status(:bad_request), "expected #{value.inspect} to be rejected"
    end
  end

  it "accepts a report right at the size cap" do
    at_cap = { "blocked-uri" => "a" * (max_bytes - envelope) }.to_json
    expect(at_cap.bytesize).to eq(max_bytes)

    post_report(at_cap)

    expect(response).to have_http_status(:no_content)
  end

  it "rejects a report one byte over the size cap" do
    over = { "blocked-uri" => "a" * (max_bytes - envelope + 1) }.to_json

    post_report(over)

    expect(response).to have_http_status(:bad_request)
  end
end
