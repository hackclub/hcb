# frozen_string_literal: true

require "rails_helper"

# See spec/support/admin_ui_parity_helpers.rb.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  include AdminUiParityHelpers
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "index filter forms submit the same params as before" do
    {
      users: %w[access_level event_id locked q referral_program_id],
      # hcb_codes' dates come from the JS date-range picker (asserted below).
      hcb_codes: %w[has_receipt q],
    }.each do |action, expected|
      it "##{action}" do
        get action

        expect(response).to have_http_status(:ok)
        path = "/admin/#{action}"
        expect(form_fields("get", path)).to eq(expected.sort)
      end
    end

    it "hcb_codes still filters by start_date/end_date through the date-range picker" do
      get :hcb_codes, params: { start_date: "2025-12-01", end_date: "2025-12-31" }

      picker = page.at_css("[data-controller=date-range-picker]")
      expect(picker["data-date-range-picker-name-start-value"]).to eq("start_date")
      expect(picker["data-date-range-picker-name-end-value"]).to eq("end_date")
      expect(picker["data-date-range-picker-initial-start-value"]).to eq("2025-12-01")
      expect(picker["data-date-range-picker-initial-end-value"]).to eq("2025-12-31")
    end
  end

  describe "filters reflect the current search" do
    it "on the users table" do
      get :users, params: { q: "orpheus", access_level: "admin", locked: "1" }

      form = filter_form(users_admin_index_path)
      expect(form.at_css("input[name=q]")["value"]).to eq("orpheus")
      expect(form.at_css("select[name=access_level] option[selected]")["value"]).to eq("admin")
      expect(form.at_css("input[type=checkbox][name=locked]")["checked"]).to be_present
    end

    it "on the HCB codes table" do
      get :hcb_codes, params: { q: "HCB-000", has_receipt: "lost" }

      form = filter_form(hcb_codes_admin_index_path)
      expect(form.at_css("input[name=q]")["value"]).to eq("HCB-000")
      expect(form.at_css("select[name=has_receipt] option[selected]")["value"]).to eq("lost")
    end
  end

  describe "CSV exports" do
    def export_link
      page.css("a").find { |a| a["href"].to_s.include?(".csv") }
    end

    it "users: carries the active filters to the CSV, minus pagination" do
      get :users, params: { q: "orpheus", access_level: "admin", page: "2" }

      uri = URI.parse(export_link["href"])
      expect(uri.path).to eq("/admin/users.csv")
      query = Rack::Utils.parse_query(uri.query)
      expect(query).to include("q" => "orpheus", "access_level" => "admin")
      # The CSV ignores pagination, so dropping it changes nothing.
      expect(query).not_to have_key("page")
    end

    it "hcb codes: carries the active filters to the CSV" do
      get :hcb_codes, params: { has_receipt: "no", start_date: "2025-12-01" }

      uri = URI.parse(export_link["href"])
      expect(uri.path).to eq("/admin/hcb_codes.csv")
      expect(Rack::Utils.parse_query(uri.query)).to include("has_receipt" => "no", "start_date" => "2025-12-01")
    end

    it "the exported CSV matches the filtered rows" do
      create(:user, full_name: "Orpheus Dinosaur")
      create(:user, full_name: "Heidi Hakkuun")

      get :users, params: { q: "Orpheus" }
      get :users, params: Rack::Utils.parse_query(URI.parse(export_link["href"]).query), format: :csv

      expect(response.body).to include("Orpheus Dinosaur")
      expect(response.body).not_to include("Heidi Hakkuun")
    end
  end
end
