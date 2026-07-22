# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Referral::LinksController", type: :request do
  let(:creator) { create(:user, verified: true) }
  let(:program) { Referral::Program.create!(name: "Referral test program", creator:) }
  let(:link)    { program.links.create!(name: "Primary", creator:) }

  describe "GET /referrals/:slug" do
    it "creates a session for an anonymous visitor so the attribution can bind on signup" do
      expect { get "/referrals/#{link.slug}" }.to change { User::Session.count }.by(1)

      expect(Referral::Attribution.last.user_session).to eq(User::Session.last)
    end

    it "does not create a session for an unrecognized slug" do
      expect { get "/referrals/not-a-real-slug" }.not_to(change { User::Session.count })
    end
  end

  it "does not create a session for an ordinary anonymous request" do
    expect { get funders_path }.not_to(change { User::Session.count })
  end
end
