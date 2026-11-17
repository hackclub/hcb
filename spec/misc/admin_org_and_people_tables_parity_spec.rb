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
      applications: %w[include_archived q],
      contracts: %w[q service status type],
      emails: %w[q to user_id],
      employee_payments: %w[q],
      employees: %w[q],
      events: %w[active activity_since approved country demo_mode engaged funded hidden omitted organized_by pending plan point_of_contact_id q rejected risk_level sort_by tagged_with transparent unapproved],
      google_workspaces: %w[configuring event_id needs_ops_review pending_deletion q revocation_present verification_error],
      # balances' `format` / `monthly_breakdown` come from its export buttons (asserted below).
      balances: %w[active activity_since approved country demo_mode end_date engaged funded hidden omitted organized_by pending plan point_of_contact_id q rejected risk_level sort_by start_date tagged_with transparent unapproved],
    }.each do |action, expected|
      it "##{action}" do
        get action

        expect(response).to have_http_status(:ok)
        path = "/admin/#{action}"
        expect(form_fields("get", path)).to eq(expected.sort)
      end
    end
  end

  describe "filters reflect the current search" do
    it "on the organizations table" do
      get :events, params: {
        q: "robotics", transparent: "transparent", omitted: "omitted", demo_mode: "demo",
        active: "active", hidden: "hidden", funded: "funded", organized_by: "teenagers",
        sort_by: "balance_asc", activity_since: "2025-12-01", pending: "1", approved: "1",
      }

      form = filter_form(events_admin_index_path)
      selected = ->(name) { form.at_css("select[name=#{name}] option[selected]")&.[]("value") }

      expect(form.at_css("input[name=q]")["value"]).to eq("robotics")
      expect(selected.call("transparent")).to eq("transparent")
      expect(selected.call("omitted")).to eq("omitted")
      expect(selected.call("demo_mode")).to eq("demo")
      expect(selected.call("active")).to eq("active")
      expect(selected.call("hidden")).to eq("hidden")
      expect(selected.call("funded")).to eq("funded")
      expect(selected.call("organized_by")).to eq("teenagers")
      expect(selected.call("sort_by")).to eq("balance_asc")
      expect(form.at_css("input[name=activity_since]")["value"]).to eq("2025-12-01")
      expect(form.at_css("input[type=checkbox][name=pending]")["checked"]).to be_present
      expect(form.at_css("input[type=checkbox][name=approved]")["checked"]).to be_present
    end

    it "on the balances report's date range" do
      get :balances, params: { start_date: "2025-01-01", end_date: "2025-06-30" }

      form = filter_form(balances_admin_index_path)
      expect(form.at_css("input[name=start_date]")["value"]).to eq("2025-01-01")
      expect(form.at_css("input[name=end_date]")["value"]).to eq("2025-06-30")
    end
  end

  describe "balances export buttons" do
    it "still submit the format / monthly breakdown the controller looks for" do
      get :balances

      form = filter_form(balances_admin_index_path)
      buttons = form.css("button[type=submit], button:not([type])")
      csv = buttons.find { |b| b["name"] == "format" && b["value"] == "csv" }
      json = buttons.find { |b| b["name"] == "format" && b["value"] == "json" }
      breakdown = buttons.find { |b| b["name"] == "monthly_breakdown" }

      expect(csv["formtarget"]).to eq("_blank")
      expect(json["formtarget"]).to eq("_blank")
      expect(breakdown["value"]).to eq("true")
      expect(breakdown["formaction"]).to eq("/admin/balances.csv")
    end
  end

  describe "organization exports and creation" do
    it "organizations: export still links to the filtered CSV" do
      create(:event)

      get :events, params: { q: "zz" }

      expect(page.css("a, button").map(&:text).join).to include("Export")
    end

    it "organizations: links to creating an org, by hand or from Airtable" do
      get :events

      hrefs = page.css("a").map { |a| a["href"] }
      expect(hrefs).to include(event_new_admin_index_path, event_new_from_airtable_admin_index_path)
    end
  end

  describe "organizations table actions" do
    it "offers Process for orgs awaiting review, and Edit + Review for the rest" do
      pending_event = create(:event, aasm_state: :pending, name: "Pending Club")
      approved_event = create(:event, aasm_state: :approved, name: "Approved Club")

      get :events

      pending_row = page.css("tbody tr").find { |tr| tr.at_css("td")&.text&.strip == pending_event.id.to_s }
      approved_row = page.css("tbody tr").find { |tr| tr.at_css("td")&.text&.strip == approved_event.id.to_s }

      expect(pending_row.css("a").map(&:text)).to include("Process")
      expect(pending_row.css("a").map { |a| a["href"] }).not_to include(edit_event_path(pending_event, tab: "admin"))

      expect(approved_row.css("a").map(&:text)).to include("Review")
      expect(approved_row.css("a").map { |a| a["href"] }).to include(edit_event_path(approved_event, tab: "admin"))
    end
  end
end

RSpec.describe DocumentsController, type: :controller do
  include SessionSupport
  render_views

  it "still lets auditors (not just admins) see common documents, now in the admin shell" do
    create_session(create(:user, :make_auditor), verified: true)

    get :common_index

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HCB Admin")
    expect(response.body).to include("Common documents")
  end

  it "still links admins to uploading a common document" do
    create_session(create(:user, :make_admin), verified: true)

    get :common_index

    expect(response.body).to include(new_document_path)
  end
end
