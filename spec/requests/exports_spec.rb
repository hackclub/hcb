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

    it "returns a 400 instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end

    it "returns a 400 instead of raising on an unparseable end_date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end

    it "returns a 400 for a month that has not ended yet" do
      get "/exports/#{event.slug}.pdf", params: { start_date: Date.today.beginning_of_month.to_s }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Can not create a financial statement for #{Date.today.strftime("%B %Y")}.")
    end

    it "returns a 400 when the end date is before the start date" do
      get "/exports/#{event.slug}.pdf", params: { start_date: last_month, end_date: Date.today.prev_month(3).to_s }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("End date cannot be before the start date.")
    end
  end

  describe "GET /exports/:event.csv" do
    it "serves the CSV for a valid month" do
      get "/exports/#{event.slug}.csv", params: { start_date: last_month }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end

    it "returns a 400 instead of raising on an unparseable start_date" do
      get "/exports/#{event.slug}.csv", params: { start_date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid date.")
    end
  end
end
