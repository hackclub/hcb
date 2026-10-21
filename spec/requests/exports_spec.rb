# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction exports", type: :request do
  let(:event) { create(:event, is_public: true) }
  let(:last_month) { Date.today.prev_month.beginning_of_month.to_s }

  describe "GET /exports/:event.pdf" do
    it "renders the statement for a valid month" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "redirects with an error instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: "not-a-date" }

      expect(response).to redirect_to(event_statements_path(event))
      expect(flash[:error]).to eq("Invalid date.")
    end

    it "redirects with an error instead of raising on an unparseable end_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: "not-a-date" }

      expect(response).to redirect_to(event_statements_path(event))
      expect(flash[:error]).to eq("Invalid date.")
    end

    it "redirects with an error for a month that has not ended yet" do
      get "/exports/#{event.slug}.pdf", params: { start_date: Date.today.beginning_of_month.to_s }

      expect(response).to redirect_to(event_statements_path(event))
      expect(flash[:error]).to start_with("Can not create a financial statement for")
    end

    it "redirects with an error when the end date is before the start date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: Date.today.prev_month(3).to_s }

      expect(response).to redirect_to(event_statements_path(event))
      expect(flash[:error]).to eq("End date cannot be before the start date.")
    end
  end

  describe "GET /exports/:event.csv" do
    it "serves the CSV for a valid month" do
      get "/exports/#{event.slug}.csv", params: { start_date: last_month }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end

    it "redirects with an error instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.csv", params: { start_date: "not-a-date" }

      expect(response).to redirect_to(event_statements_path(event))
      expect(flash[:error]).to eq("Invalid date.")
    end
  end
end
