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

      it "sends a welcome DM with a signed link when the bot is added to a server" do
        bot = instance_double(Discordrb::Bot, pm_channel: "channel")
        allow(Discord::Bot).to receive(:bot).and_return(bot)
        sent_message = nil
        allow(bot).to receive(:send_message) { |_channel, message| sent_message = message }

        body = { type: 1, event: { type: "APPLICATION_AUTHORIZED", data: { integration_type: 0, user: { id: "123456789" } } } }.to_json
        timestamp, signature = discord_signature(body)

        post "/discord/event_webhook",
             params: body,
             headers: {
               "X-Signature-Timestamp" => timestamp,
               "X-Signature-Ed25519"   => signature,
               "Content-Type"          => "application/json"
             }

        expect(response).to have_http_status(:no_content)
        query = Rack::Utils.parse_query(URI.parse(sent_message[/https?:\/\/\S+/]).query)
        expect(query).not_to have_key("discord_id")
        travel 23.hours do
          expect(Discord.verify_signed(query["signed_discord_id"], purpose: :link_user)).to eq("123456789")
        end
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

    describe "attach receipt modal submission" do
      let(:discord_user_id) { "111111111111111111" }
      let(:event) { create(:event, discord_guild_id: "222222222222222222", discord_channel_id: "333333333333333333") }
      let(:hcb_code) { create(:canonical_pending_transaction, event:).local_hcb_code }
      let(:receipt_url) { "https://cdn.discordapp.com/attachments/1/2/receipt.png" }
      let(:payload) do
        {
          type: 5,
          token: "interaction-token",
          guild: { id: event.discord_guild_id },
          channel: { id: event.discord_channel_id },
          member: { user: { id: discord_user_id }, permissions: "0" },
          data: {
            custom_id: "attach_receipt:#{hcb_code.hashid}",
            resolved: {
              attachments: {
                "444" => { filename: "receipt.png", content_type: "image/png", url: receipt_url }
              }
            }
          }
        }.to_json
      end

      before do
        stub_request(:get, receipt_url).to_return(body: file_fixture("receipt.png").read)
      end

      def submit_modal
        timestamp, signature = discord_signature(payload)

        post "/discord/interaction_webhook",
             params: payload,
             headers: {
               "X-Signature-Timestamp" => timestamp,
               "X-Signature-Ed25519"   => signature,
               "Content-Type"          => "application/json"
             }
      end

      it "does not attach a receipt for a Discord user who has not linked HCB" do
        allow(Discord::Bot).to receive(:bot).and_return(instance_double(Discordrb::Bot, server: nil, user: nil))

        expect { submit_modal }.not_to change(Receipt, :count)
        expect(response.parsed_body.dig("data", "content")).to include("link your Discord account")
      end

      it "does not attach a receipt for a linked user who is not in the organization" do
        create(:user, discord_id: discord_user_id)

        expect { submit_modal }.not_to change(Receipt, :count)
        expect(response.parsed_body.dig("data", "content")).to include("don't have permission")
      end

      it "attaches the receipt as the linked organization member" do
        user = create(:user, discord_id: discord_user_id)
        create(:organizer_position, user:, event:)

        expect { submit_modal }.to change(Receipt, :count).by(1)
        expect(Receipt.last).to have_attributes(user:, receiptable: hcb_code, upload_method: "discord_bot_modal")
      end
    end
  end
end
