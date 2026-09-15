# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AiBlazerQueriesController do
  include SessionSupport
  render_views

  describe "#index" do
    it "renders only AI-prefixed queries" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      Blazer::Query.create!(name: "[AI] Donation query", statement: "SELECT 1", data_source: "main")
      Blazer::Query.create!(name: "Manual query", statement: "SELECT 2", data_source: "main")

      get(:index)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("[AI] Donation query")
      expect(response.body).not_to include("Manual query")
    end
  end

  describe "#create" do
    it "creates an AI-prefixed Blazer query with prompt comment" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      generator = instance_double(Blazer::AiQueryGenerator)
      allow(Blazer::AiQueryGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:run!).and_return({ name: "Donation totals", statement: "SELECT 1" })

      post(
        :create,
        params: {
          ai_blazer_query: {
            prompt: "Show donation totals"
          }
        }
      )

      query = Blazer::Query.last

      expect(response).to redirect_to(admin_ai_blazer_query_path(query))
      expect(query.name).to eq("[AI] Donation totals")
      expect(query.statement).to start_with("/* AI prompt: Show donation totals */")
      expect(query.creator_id).to eq(admin.id)
    end
  end

  describe "#show" do
    it "returns not found for non-AI queries" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      query = Blazer::Query.create!(name: "Manual", statement: "SELECT 1", data_source: "main")

      expect { get(:show, params: { id: query.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
