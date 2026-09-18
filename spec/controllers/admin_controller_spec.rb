# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport

  describe "#disbursement_process" do
    render_views

    it "renders mission statements for the source and destination events" do
      admin = create(:user, :make_admin)
      source_event = create(:event, description: "Source mission statement")
      destination_event = create(:event, description: "Destination mission statement")
      disbursement = create(:disbursement, source_event:, event: destination_event)

      create_session(admin, verified: true)

      get :disbursement_process, params: { id: disbursement.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Source mission statement")
      expect(response.body).to include("Destination mission statement")
    end
  end

  describe "#ach_start_approval" do
    render_views

    it "renders the ach transfer event's mission statement" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance, description: "Money wiring mission statement")
      ach_transfer = create(:ach_transfer, event:)

      create_session(admin, verified: true)

      get :ach_start_approval, params: { id: ach_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Money wiring mission statement")
    end
  end

  describe "#event_search" do
    it "returns JSON options the combobox can render" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == event.id.to_s }
      expect(option).to include("value" => event.id.to_s, "sublabel" => event.slug)
    end

    # The dropdown labels have to match what `combobox_tag` renders for the
    # preselected value, or re-picking the same org silently changes the text.
    it "labels options with the admin display for an admin" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      event = create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      labels = JSON.parse(response.body).map { |o| o["label"] }
      expect(labels).to include("Hack Club HQ (ID: #{event.id})")
    end

    it "labels options with the plain name for a non-admin auditor" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      create(:event, name: "Hack Club HQ")

      get(:event_search, params: { q: "Hack Club HQ" }, format: :json)

      expect(JSON.parse(response.body).map { |o| o["label"] }).to include("Hack Club HQ")
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:event_search, params: { q: "ysws", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page2.size).to eq(1)
      expect(page1 & page2).to be_empty
    end

    it "clamps non-positive page numbers to the first page" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      3.times { |i| create(:event, name: "ysws #{i}") }

      get(:event_search, params: { q: "ysws", page: 0 }, format: :json)

      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "#user_search" do
    # The admin label spells out the email and ID, so repeating them in the
    # sublabel wrapped every row to several lines.
    it "gives an admin the detailed label and no redundant sublabel" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      expect(response).to have_http_status(:ok)
      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option["label"]).to eq("Jane Doe (Email: #{user.email}, ID: #{user.id})")
      expect(option["sublabel"]).to be_nil
    end

    it "gives a non-admin auditor the plain name with the email as a sublabel" do
      auditor = create(:user, :make_auditor)
      create_session(auditor, verified: true)
      user = create(:user, full_name: "Jane Doe")

      get(:user_search, params: { q: "Jane Doe" }, format: :json)

      option = JSON.parse(response.body).find { |o| o["value"] == user.id.to_s }
      expect(option["label"]).to eq("Jane Doe")
      expect(option["sublabel"]).to eq(user.email)
    end

    it "paginates results without overlap across pages" do
      stub_const("ComboboxSearchable::PAGE_SIZE", 2)
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      ["Searchable Personone", "Searchable Persontwo", "Searchable Personthree"].each do |name|
        create(:user, full_name: name)
      end

      get(:user_search, params: { q: "Searchable", page: 1 }, format: :json)
      page1 = JSON.parse(response.body).map { |o| o["value"] }
      get(:user_search, params: { q: "Searchable", page: 2 }, format: :json)
      page2 = JSON.parse(response.body).map { |o| o["value"] }

      expect(page1.size).to eq(2)
      expect(page1 & page2).to be_empty
    end
  end
end
