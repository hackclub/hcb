# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discord::ProcessNotificationJob do
  include Rails.application.routes.url_helpers

  let(:event) { create(:event, discord_guild_id: "222222222222222222", discord_channel_id: "333333333333333333") }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
  # Specs run with PublicActivity disabled; the notification is about the activity.
  let(:raw_pending_stripe_transaction) { PublicActivity.with_tracking { create(:raw_pending_stripe_transaction, stripe_card:, amount_cents: -1000) } }
  let(:activity) { raw_pending_stripe_transaction.activities.find_by!(key: "raw_pending_stripe_transaction.create") }
  let(:bot) { instance_double(Discordrb::Bot) }
  let(:sent_messages) { [] }

  before do
    activity # created up front, so the jobs its creation enqueues stay out of the examples' expectations
    allow(Discord::Bot).to receive(:bot).and_return(bot)
    allow(bot).to receive(:send_message) do |*args|
      sent_messages << args
      double(id: "444444444444444444")
    end
  end

  def embed = sent_messages.last[3]

  def buttons = sent_messages.last[7].flat_map { |row| row[:components] }

  context "with a card charge whose ledger item exists" do
    let(:cpt) { create(:canonical_pending_transaction, event:, amount_cents: -1000, raw_pending_stripe_transaction:) }
    let(:item) { cpt.ledger_item }

    before { item }

    it "links the charge's ledger item" do
      described_class.perform_now(activity.id)

      expect(embed[:description]).to eq("#{stripe_card.user.name} spent $10.00 on [#{item.memo}](#{ledger_item_url(item)}) for [#{event.name}](#{event_url(event)})")
      expect(buttons.map { |button| button.slice(:label, :url, :custom_id) }).to eq([
                                                                                      { label: "View transaction", url: ledger_item_url(item) },
                                                                                      { label: "Attach receipt", custom_id: "attach_receipt" }
                                                                                    ])
      expect(Discord::Message.last).to have_attributes(activity:, discord_message_id: "444444444444444444", discord_channel_id: event.discord_channel_id)
    end

    it "says whose card was declined" do
      cpt.decline!
      expect(item.reload).to be_declined

      described_class.perform_now(activity.id)

      expect(embed[:description]).to eq("#{stripe_card.user.possessive_name} [#{event.name}](#{event_url(event)}) card was declined for $10.00 at #{item.memo}")
    end

    context "for a cash withdrawal" do
      let(:raw_pending_stripe_transaction) { PublicActivity.with_tracking { create(:raw_pending_stripe_transaction, stripe_card:, amount_cents: -1000, stripe_merchant_category_code: "6011") } }

      it "says the cardholder withdrew the amount" do
        described_class.perform_now(activity.id)

        expect(embed[:description]).to eq("#{stripe_card.user.name} withdrew $10.00 from Merchant 1 for [#{event.name}](#{event_url(event)})")
      end
    end
  end

  context "before the card charge's ledger item exists" do
    it "waits for it" do
      expect { described_class.perform_now(activity.id) }.to have_enqueued_job(described_class).with(activity.id, attempt: 2)

      expect(sent_messages).to be_empty
      expect(Discord::Message.count).to eq(0)
    end

    it "sends the notification without a link once it has waited long enough" do
      expect { described_class.perform_now(activity.id, attempt: described_class::LEDGER_ITEM_RETRY_LIMIT) }.not_to have_enqueued_job(described_class)

      expect(embed[:description]).to eq("#{stripe_card.user.name} spent $10.00 on merchant 1")
      expect(buttons.map { |button| button[:label] }).to eq(["Attach receipt"])
    end
  end
end
