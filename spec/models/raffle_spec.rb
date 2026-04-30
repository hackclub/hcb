# frozen_string_literal: true

require "rails_helper"

RSpec.describe Raffle, type: :model do
  describe ".generate_ticket_number" do
    it "draws ticket numbers from a cryptographically secure random source" do
      srand(424242)
      first_run = 5.times.map { described_class.generate_ticket_number }

      srand(424242)
      second_run = 5.times.map { described_class.generate_ticket_number }

      expect(first_run).not_to eq(second_run),
                               "Raffle.generate_ticket_number is reproducible from a known PRNG seed " \
                               "(first run #{first_run.inspect}, second run #{second_run.inspect}). " \
                               "Use SecureRandom (or another CSPRNG) so ticket numbers are not predictable."
    end

    it "enforces ticket_number uniqueness with a database-level unique index" do
      indexes = ActiveRecord::Base.connection.indexes(:raffles)
      ticket_index = indexes.find { |i| i.columns == ["ticket_number"] && i.unique }

      expect(ticket_index).to be_present,
                              "raffles.ticket_number lacks a UNIQUE database index. The model-level " \
                              "`validates :ticket_number, uniqueness: true` is racy: two concurrent " \
                              "saves whose generated numbers collide can both pass validation and " \
                              "INSERT successfully. Add a unique index so the DB enforces the invariant."
    end
  end

  describe "confirmation state" do
    let(:user) { create(:user) }

    it "auto-confirms raffles for programs that don't require confirmation" do
      raffle = described_class.create!(user:, program: "first-worlds-2026-printer")

      expect(raffle).to be_confirmed
      expect(raffle).not_to be_pending
    end

    it "creates raffles in a pending state for programs requiring confirmation" do
      raffle = described_class.create!(user:, program: "first-worlds-2026-airpods")

      expect(raffle).to be_pending
      expect(raffle).not_to be_confirmed
    end

    it "lists the airpods program as requiring confirmation" do
      expect(Raffle::PROGRAMS_REQUIRING_CONFIRMATION).to include("first-worlds-2026-airpods")
    end

    describe "#confirm!" do
      it "flips a pending raffle to confirmed" do
        raffle = described_class.create!(user:, program: "first-worlds-2026-airpods")

        expect { raffle.confirm! }.to change { raffle.reload.confirmed? }.from(false).to(true)
      end

      it "is a no-op on already-confirmed raffles" do
        raffle = described_class.create!(user:, program: "first-worlds-2026-printer")

        expect { raffle.confirm! }.not_to(change { raffle.reload.updated_at })
      end
    end
  end
end
