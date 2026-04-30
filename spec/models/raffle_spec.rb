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
end
