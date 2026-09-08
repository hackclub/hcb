# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementsController do
  include SessionSupport

  describe "#event_search" do
    def labels
      JSON.parse(response.body).map { |option| option["label"] }
    end

    def label_for(event)
      "#{event.name} (#{event.id})"
    end

    # The endpoint only returns 25 rows, and the caller's own organizations are
    # ordered first. An organization whose name is a prefix of many others
    # ("YSWS" vs. "YSWS - ...") used to fall off the end of that window.
    it "returns the exact match even when swamped by partial matches" do
      user = create(:user, access_level: :admin)
      30.times { |i| create(:organizer_position, user:, event: create(:event, name: "YSWS - Project #{i}")) }
      exact = create(:event, name: "YSWS")

      create_session(user, verified: true)

      get :event_search, params: { q: "YSWS" }, format: :json

      expect(labels.first).to eq(label_for(exact))
    end

    it "ranks exact, then prefix, then substring matches" do
      user = create(:user, access_level: :admin)
      substring = create(:event, name: "Big YSWS Thing")
      prefix = create(:event, name: "YSWS - Project")
      exact = create(:event, name: "YSWS")

      create_session(user, verified: true)

      get :event_search, params: { q: "ysws" }, format: :json

      expect(labels).to eq([exact, prefix, substring].map { |event| label_for(event) })
    end
  end
end
