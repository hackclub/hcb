# frozen_string_literal: true

require "rails_helper"

RSpec.describe DonationService::Donors do
  let(:event) { create(:event) }

  subject(:donors) { described_class.new(event) }

  # `succeeded_and_not_refunded` only counts these states.
  def donate(amount:, email:, name: Faker::Name.unique.name, anonymous: false, at: Time.current)
    create(
      :donation,
      event:,
      amount:,
      email:,
      name:,
      anonymous:,
      aasm_state: :in_transit,
      in_transit_at: at
    )
  end

  describe "#top" do
    it "returns [] when there are fewer than three donors" do
      donate(amount: 100, email: "a@example.com")
      donate(amount: 200, email: "b@example.com")

      expect(donors.top).to eq([])
    end

    it "aggregates by donor and orders by total amount descending" do
      donate(amount: 100, email: "a@example.com", name: "Alice")
      donate(amount: 500, email: "b@example.com", name: "Bob")
      donate(amount: 50,  email: "b@example.com", name: "Bob") # same donor, summed
      donate(amount: 300, email: "c@example.com", name: "Carol")

      result = donors.top

      expect(result.map(&:name)).to eq(%w[Bob Carol Alice])
      expect(result.map(&:amount)).to eq([550, 300, 100])
    end

    it "excludes anonymous donations and donations without an email" do
      donate(amount: 900, email: "anon@example.com", anonymous: true)
      donate(amount: 800, email: "")
      donate(amount: 100, email: "a@example.com")
      donate(amount: 200, email: "b@example.com")
      donate(amount: 300, email: "c@example.com")

      result = donors.top

      expect(result.map(&:amount)).to eq([300, 200, 100])
    end
  end

  describe "#recent" do
    it "returns [] when there are fewer than eight distinct donors" do
      7.times { |i| donate(amount: 100, email: "donor#{i}@example.com") }

      expect(donors.recent).to eq([])
    end

    it "returns the eight most recent distinct donors, newest first" do
      # An older donation from a donor who also gives most recently — the
      # donor should appear once, positioned by their latest gift.
      donate(amount: 100, email: "repeat@example.com", name: "Repeat", at: 10.days.ago)

      9.times do |i|
        donate(amount: 100, email: "donor#{i}@example.com", at: (9 - i).days.ago)
      end

      donate(amount: 100, email: "repeat@example.com", name: "Repeat", at: 1.minute.ago)

      result = donors.recent

      expect(result.size).to eq(described_class::RECENT_LIMIT)
      expect(result.first.name).to eq("Repeat")
      expect(result.map { |d| d.email }.uniq.size).to eq(result.size)
      donated_at = result.map(&:donated_at)
      expect(donated_at).to eq(donated_at.sort.reverse)
    end

    it "keeps anonymous and email-less donations as distinct recent donors" do
      donate(amount: 100, email: "", name: "No Email One")
      donate(amount: 100, email: "", name: "No Email Two")
      donate(amount: 100, email: "anon@example.com", anonymous: true)
      5.times { |i| donate(amount: 100, email: "donor#{i}@example.com") }

      expect(donors.recent.size).to eq(described_class::RECENT_LIMIT)
    end
  end
end
