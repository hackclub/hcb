# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::Session::DeleteAnonymousSessionsJob do
  def anonymous_session(expiration_at: 1.day.ago)
    create(:user_session, user: nil, expiration_at:)
  end

  it "deletes an expired anonymous session" do
    session = anonymous_session

    expect { described_class.perform_now }.to change { User::Session.exists?(session.id) }.from(true).to(false)
  end

  it "deletes the session's PaperTrail versions", versioning: true do
    session = anonymous_session
    versions = PaperTrail::Version.where(item_type: "User::Session", item_id: session.id)
    expect(versions).to exist

    described_class.perform_now

    expect(versions.reload).not_to exist
  end

  it "deletes the ownerless activities left by the pre-bf0e737f4 callback" do
    session = anonymous_session
    PublicActivity::Activity.create!(trackable: session, key: "user_session.create")

    described_class.perform_now

    expect(PublicActivity::Activity.where(trackable_type: "User::Session", trackable_id: session.id)).not_to exist
  end

  it "keeps a session that has authenticated" do
    session = create(:user_session, user: create(:user), expiration_at: 1.day.ago)

    described_class.perform_now

    expect(User::Session.exists?(session.id)).to be true
  end

  it "keeps an unexpired anonymous session so a visitor mid-signup isn't logged out" do
    session = anonymous_session(expiration_at: 1.day.from_now)

    described_class.perform_now

    expect(User::Session.exists?(session.id)).to be true
  end

  it "keeps an anonymous session that carries a referral attribution" do
    session = anonymous_session
    creator = create(:user)
    program = Referral::Program.create!(name: "Test Program", creator:)
    link = Referral::Link.create!(program:, creator:, name: "Test Link")
    Referral::Attribution.create!(user_session: session, program:, link:)

    described_class.perform_now

    expect(User::Session.exists?(session.id)).to be true
  end

  it "stops once the per-run limit is reached so a single run does bounded work" do
    Array.new(3) { anonymous_session }

    stub_const("#{described_class}::BATCH_SIZE", 1)
    deleted = described_class.new.perform(max_per_run: 2)

    expect(deleted).to eq(2)
    expect(User::Session.where(user_id: nil).count).to eq(1)
  end
end
