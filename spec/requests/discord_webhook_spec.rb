# frozen_string_literal: true

require "rails_helper"

# Pre-generated Ed25519 keypair for testing.
# Generated with: ruby -r ed25519 -e 'k = Ed25519::SigningKey.generate; puts k.seed.unpack1("H*"); puts k.verify_key.to_bytes.unpack1("H*")'
DISCORD_TEST_SIGNING_KEY_SEED = "a689dcab6e98940e48e69ddac835ec9240ef5a93d0db32db56617b7992c717d6"
DISCORD_TEST_PUBLIC_KEY = "b8e2071ed84201e2a2fe7e55a6d64f5ed6017706b3f2edde795789ff6ce7f9fb"

RSpec.describe "Discord Webhook", type: :request do
  let(:signing_key) { Ed25519::SigningKey.new([DISCORD_TEST_SIGNING_KEY_SEED].pack("H*")) }

  around do |example|
    original = ENV["DISCORD__PUBLIC_KEY"]
    ENV["DISCORD__PUBLIC_KEY"] = DISCORD_TEST_PUBLIC_KEY
    example.run
  ensure
    ENV["DISCORD__PUBLIC_KEY"] = original
  end

  def discord_signature(body, timestamp: Time.now.to_i.to_s)
    signature = signing_key.sign(timestamp + body)
    [timestamp, signature.unpack1("H*")]
  end

  describe "POST /discord/event_webhook" do
    let(:payload) { { type: 0 }.to_json }

    context "with a valid Discord signature" do
      it "returns 204" do
        timestamp, signature = discord_signature(payload)

        post "/discord/event_webhook",
             params: payload,
             headers: {
               "X-Signature-Timestamp" => timestamp,
               "X-Signature-Ed25519"   => signature,
               "Content-Type"          => "application/json"
             }

        expect(response).to have_http_status(:no_content)
      end
    end

    context "with an invalid Discord signature" do
      it "returns 401 and does not process the webhook" do
        expect(DiscordController.method_defined?(:event_webhook)).to be(true)
        expect_any_instance_of(DiscordController).not_to receive(:event_webhook)

        post "/discord/event_webhook",
             params: payload,
             headers: {
               "X-Signature-Timestamp" => Time.now.to_i.to_s,
               "X-Signature-Ed25519"   => "a" * 128,
               "Content-Type"          => "application/json"
             }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with no Discord signature" do
      it "returns 401 and does not process the webhook" do
        expect(DiscordController.method_defined?(:event_webhook)).to be(true)
        expect_any_instance_of(DiscordController).not_to receive(:event_webhook)

        post "/discord/event_webhook",
             params: payload,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /discord/interaction_webhook" do
    let(:payload) { { type: 1 }.to_json }

    context "with a valid Discord signature" do
      it "returns 200 with PONG" do
        timestamp, signature = discord_signature(payload)

        post "/discord/interaction_webhook",
             params: payload,
             headers: {
               "X-Signature-Timestamp" => timestamp,
               "X-Signature-Ed25519"   => signature,
               "Content-Type"          => "application/json"
             }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq(1)
      end
    end

    context "with an invalid Discord signature" do
      it "returns 401 and does not process the webhook" do
        expect(DiscordController.method_defined?(:interaction_webhook)).to be(true)
        expect_any_instance_of(DiscordController).not_to receive(:interaction_webhook)

        post "/discord/interaction_webhook",
             params: payload,
             headers: {
               "X-Signature-Timestamp" => Time.now.to_i.to_s,
               "X-Signature-Ed25519"   => "a" * 128,
               "Content-Type"          => "application/json"
             }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with no Discord signature" do
      it "returns 401 and does not process the webhook" do
        expect(DiscordController.method_defined?(:interaction_webhook)).to be(true)
        expect_any_instance_of(DiscordController).not_to receive(:interaction_webhook)

        post "/discord/interaction_webhook",
             params: payload,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
