# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementsController do
  include SessionSupport

  describe "#event_search" do
    it "returns the exact match even when swamped by partial matches" do
      user = create(:user, access_level: :admin)
      30.times { |i| create(:organizer_position, user:, event: create(:event, name: "YSWS - Project #{i}")) }
      exact = create(:event, name: "YSWS")

      create_session(user, verified: true)

      get :event_search, params: { q: "YSWS" }, format: :json

      labels = JSON.parse(response.body).map { |o| o["label"] }
      expect(labels).to include("#{exact.name} (#{exact.id})")
      expect(labels.first).to eq("#{exact.name} (#{exact.id})")
    end
  end
end
