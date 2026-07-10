# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, ".card_locking_candidates", type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  def candidate_ids = User.card_locking_candidates.pluck(:id)

  it "includes a user with an outstanding enforcement-era charge" do
    create_settled_card_charge(user:, settled_at: 1.hour.ago)

    expect(candidate_ids).to include(user.id)
  end

  it "includes a locked user with no outstanding charges, so they can be unlocked" do
    user.update!(cards_locked: true)

    expect(candidate_ids).to include(user.id)
  end

  it "excludes an unlocked user whose only charge is resolved" do
    settled_at = 4.days.ago
    create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.hour)

    expect(candidate_ids).not_to include(user.id)
  end
end
