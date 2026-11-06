# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchService::Engine::Users do
  let(:user) { create(:user) }
  let(:event) { create(:event) }

  before do
    create(:organizer_position, user:, event:)
  end

  def search(query)
    described_class.new({ "types" => ["user"], "query" => query }, user, {}).run
  end

  def teammate_in(event, full_name:)
    create(:user, full_name:).tap { |teammate| create(:organizer_position, user: teammate, event:) }
  end

  it "returns teammates from the user's organizations" do
    teammate = teammate_in(event, full_name: "Zephyrine Teammate")

    expect(search("Zephyrine")).to contain_exactly(teammate)
  end

  it "does not return organizers of unrelated organizations" do
    teammate_in(create(:event), full_name: "Zephyrine Stranger")

    expect(search("Zephyrine")).to be_empty
  end

  it "does not return teammates from a deleted organization" do
    deleted_event = create(:event)
    create(:organizer_position, user:, event: deleted_event)
    teammate_in(deleted_event, full_name: "Zephyrine Former")
    deleted_event.destroy!

    expect(search("Zephyrine")).to be_empty
  end

  it "does not return teammates from an organization the user was removed from" do
    left_event = create(:event)
    create(:organizer_position, user:, event: left_event).destroy!
    teammate_in(left_event, full_name: "Zephyrine Former")

    expect(search("Zephyrine")).to be_empty
  end
end
