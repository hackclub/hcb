# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnstileService::Verify do
  let(:token) { "0.abc123" }
  let(:action) { TurnstileService::SMS_VERIFICATION_ACTION }
  let(:hostname) { "hcb.hackclub.com" }

  before { allow(TurnstileService).to receive(:secret_key).and_return("0x0000secret") }

  def stub_siteverify(body)
    stub_request(:post, described_class::SITEVERIFY_URL)
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def run(token: self.token)
    described_class.new(token:, action:, hostname:, remote_ip: "1.2.3.4").run
  end

  it "passes a token Cloudflare accepts for the expected action and hostname" do
    stub_siteverify({ "success" => true, "action" => action, "hostname" => hostname })

    expect(run).to be true
  end

  it "sends the secret, the token, and the caller's IP to Cloudflare" do
    stub_siteverify({ "success" => true, "action" => action, "hostname" => hostname })

    run

    expect(
      a_request(:post, described_class::SITEVERIFY_URL).with { |req|
        URI.decode_www_form(req.body).to_h == {
          "secret" => "0x0000secret", "response" => token, "remoteip" => "1.2.3.4"
        }
      }
    ).to have_been_made
  end

  it "rejects a token Cloudflare marks unsuccessful" do
    stub_siteverify({ "success" => false, "error-codes" => ["invalid-input-response"] })

    expect(run).to be false
  end

  # A token minted by any other widget on our sitekey must not be usable
  # against the phone-verification flow.
  it "rejects a token solved for a different action" do
    stub_siteverify({ "success" => true, "action" => "some-other-form", "hostname" => hostname })

    expect(run).to be false
  end

  # Without this, a token solved on any other site sharing our sitekey passes.
  it "rejects a token solved on a different hostname" do
    stub_siteverify({ "success" => true, "action" => action, "hostname" => "evil.example" })

    expect(run).to be false
  end

  it "rejects a blank token without calling Cloudflare" do
    expect(run(token: "")).to be false
    expect(a_request(:post, described_class::SITEVERIFY_URL)).not_to have_been_made
  end

  it "rejects a token longer than Cloudflare issues without calling Cloudflare" do
    expect(run(token: "a" * (described_class::MAX_TOKEN_LENGTH + 1))).to be false
    expect(a_request(:post, described_class::SITEVERIFY_URL)).not_to have_been_made
  end

  # `cf-turnstile-response[]=x` arrives as an array, not a string.
  it "rejects a token that isn't a string" do
    expect(run(token: ["0.abc123"])).to be false
    expect(a_request(:post, described_class::SITEVERIFY_URL)).not_to have_been_made
  end

  it "fails closed when Cloudflare is unreachable" do
    stub_request(:post, described_class::SITEVERIFY_URL).to_timeout
    allow(Rails.error).to receive(:report)

    expect(run).to be false
  end

  it "fails closed when Cloudflare returns an error status" do
    stub_request(:post, described_class::SITEVERIFY_URL).to_return(status: 500, body: "")
    allow(Rails.error).to receive(:unexpected)

    expect(run).to be false
  end
end
