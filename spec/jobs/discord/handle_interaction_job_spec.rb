# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discord::HandleInteractionJob do
  include Rails.application.routes.url_helpers

  let(:discord_user_id) { "111111111111111111" }
  let(:event) { create(:event, discord_guild_id: "222222222222222222", discord_channel_id: "333333333333333333") }

  before do
    allow(Discord::Bot).to receive(:bot).and_return(instance_double(Discordrb::Bot, server: nil, user: nil))
  end

  def interaction_payload(interaction)
    {
      token: "interaction-token",
      guild: { id: event.discord_guild_id },
      channel: { id: event.discord_channel_id },
      member: { user: { id: discord_user_id }, permissions: "0" },
    }.deep_merge(interaction).with_indifferent_access
  end

  # Components and modals are answered inline (responded: false), so the job
  # returns the response Discord would get.
  def perform(interaction)
    described_class.perform_now(interaction_payload(interaction), responded: false)
  end

  # Commands are acknowledged by the webhook first (responded: true), so the
  # job patches its response onto the acknowledgement.
  def perform_command(interaction)
    response = nil
    connection = instance_double(Faraday::Connection)
    allow(Discord::Bot).to receive(:faraday_connection).and_return(connection)
    allow(connection).to receive(:patch) do |_path, body|
      response = body
      instance_double(Faraday::Response, body: body)
    end

    described_class.perform_now(interaction_payload(interaction), responded: true)

    response
  end

  describe "/transactions" do
    let(:interaction) { { type: Discordrb::Interaction::TYPES[:command], data: { name: "transactions" } } }

    it "lists the organization's ledger items, pending first" do
      settled = create(:canonical_transaction, event:, amount_cents: -2000, date: 1.day.ago).ledger_item
      pending = create(:canonical_pending_transaction, event:, amount_cents: -1000, date: 3.days.ago).ledger_item
      create(:canonical_transaction, amount_cents: -3000) # another organization's

      fields = perform_command(interaction).dig(:embeds, 0, :fields)

      expect(fields).to eq([
                             { name: "[PENDING] \"#{pending.memo}\" for -$10.00", value: "On #{pending.datetime.strftime('%B %d, %Y')} - [Details](#{ledger_item_url(pending)})" },
                             { name: "\"#{settled.memo}\" for -$20.00", value: "On #{settled.datetime.strftime('%B %d, %Y')} - [Details](#{ledger_item_url(settled)})" },
                           ])
    end

    it "says when there are none" do
      expect(perform_command(interaction).dig(:embeds, 0, :description)).to eq("No transactions yet...")
    end
  end

  describe "the attach receipt button" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
    # Specs run with PublicActivity disabled; the button finds its charge through the activity.
    let(:raw_pending_stripe_transaction) { PublicActivity.with_tracking { create(:raw_pending_stripe_transaction, stripe_card:) } }
    let(:item) { create(:canonical_pending_transaction, event:, amount_cents: -1000, raw_pending_stripe_transaction:).ledger_item }
    let(:activity) { raw_pending_stripe_transaction.activities.find_by!(key: "raw_pending_stripe_transaction.create") }
    let(:discord_message) { Discord::Message.create!(discord_channel_id: event.discord_channel_id, discord_guild_id: event.discord_guild_id, discord_message_id: "444444444444444444", activity:) }
    let(:interaction) { { type: Discordrb::Interaction::TYPES[:component], data: { custom_id: "attach_receipt" }, message: { id: discord_message.discord_message_id } } }

    before { item }

    it "opens a modal for the charge's ledger item" do
      user = create(:user, discord_id: discord_user_id)
      create(:organizer_position, user:, event:)

      response = perform(interaction)

      expect(response[:type]).to eq(Discordrb::Interaction::CALLBACK_TYPES[:modal])
      expect(response[:data]).to include(custom_id: "attach_receipt:#{item.hashid}", title: "$10.00 for #{item.memo}")
    end

    it "requires a linked HCB account" do
      expect(perform(interaction).dig(:data, :content)).to include("link your Discord account")
    end

    it "refuses a linked user who may not upload receipts for the charge" do
      create(:user, discord_id: discord_user_id)

      expect(perform(interaction).dig(:data, :content)).to include("don't have permission")
    end

    it "refuses a message it did not send" do
      create(:user, discord_id: discord_user_id)

      expect(perform(interaction.deep_merge(message: { id: "555555555555555555" })).dig(:data, :content)).to include("Could not find the transaction")
    end
  end
end
