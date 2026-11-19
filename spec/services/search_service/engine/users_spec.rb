# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchService::Engine::Users do
  def search(user)
    described_class.new({ "types" => ["user"], "query" => "Zebulon" }, user, {}).run
  end

  it "only returns users who share an active organization with a non-auditor" do
    searcher = create(:user)
    event = create(:event)
    create(:organizer_position, user: searcher, event:)

    teammate = create(:user, full_name: "Zebulon Teammate")
    create(:organizer_position, user: teammate, event:)

    former_teammate = create(:user, full_name: "Zebulon Former")
    create(:organizer_position, user: former_teammate, event:).destroy!

    stranger = create(:user, full_name: "Zebulon Stranger")
    create(:organizer_position, user: stranger)

    deleted_event = create(:event)
    create(:organizer_position, user: searcher, event: deleted_event)
    deleted_event_teammate = create(:user, full_name: "Zebulon Deleted")
    create(:organizer_position, user: deleted_event_teammate, event: deleted_event)
    deleted_event.destroy!

    expect(search(searcher)).to contain_exactly(teammate)
  end

  it "returns no other users when the non-auditor has no organizations" do
    create(:organizer_position, user: create(:user, full_name: "Zebulon Stranger"))

    expect(search(create(:user))).to be_empty
  end
end
