# frozen_string_literal: true

require "rails_helper"

# `combobox_tag` is rendered on ~25 pages. These guard the helper's contract
# with its call sites: that each page still renders a wired-up combobox.
RSpec.describe "combobox rendering" do
  include SessionSupport

  describe AdminController, type: :controller do
    render_views

    it "renders every admin page that uses combobox_tag" do
      admin = create(:user, :make_admin)
      create(:event, name: "Hack Club HQ")
      create_session(admin, verified: true)

      %i[
        ach checks donations invoices users disbursements recurring_donations
        sponsors bank_fees wires reimbursements account_numbers google_workspaces
        paypal_transfers wise_transfers ledger pending_ledger
        stripe_card_personalization_designs
      ].each do |action|
        get action

        expect(response).to have_http_status(:ok), "#{action} returned #{response.status}"
        expect(response.body).to include('data-controller="combobox"'), "#{action} rendered no combobox"
      end
    end

    # The bulk-map control at the bottom of the ledger shares a field name with
    # the filter form at the top, so it has to override the derived DOM id.
    it "does not emit a duplicate DOM id on the ledger's two event fields" do
      admin = create(:user, :make_admin)
      create_session(admin, verified: true)

      get :ledger

      doc = Nokogiri::HTML(response.body)
      combobox_ids = doc.css("input[role=combobox]").map { |el| el["id"] }
      all_ids = doc.css("[id]").map { |el| el["id"] }.tally

      expect(combobox_ids).to include("event_id", "bulk_map_event_id")
      expect(combobox_ids.map { |id| all_ids[id] }).to all(eq(1))
    end
  end

  describe EventsController, type: :controller do
    render_views

    it "renders the parent organization picker in event settings" do
      admin = create(:user, :make_admin)
      event = create(:event)
      # Unrelated to the combobox, and would otherwise reach out to Airtable.
      allow_any_instance_of(Event).to receive(:airtable_record).and_return(nil)
      Flipper.enable(:parent_event_assignment_2025_09_18)
      create_session(admin, verified: true)

      get :edit, params: { id: event.slug, tab: "admin" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="combobox"')
    end
  end

  describe DisbursementsController, type: :controller do
    render_views

    it "renders the transfer form with two comboboxes wired for swapping" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance)
      create_session(admin, verified: true)

      get :new, params: { event_id: event.slug }

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('data-swap-organizations-target="combobox"').size).to eq(2)
    end
  end

  describe SponsorsController, type: :controller do
    render_views

    # The picker and the fallback hidden field both submit `sponsor[event_id]`.
    # An auditor who is also a member of the org reaches this form and sees the
    # picker, so the fallback must not render alongside it — the later field
    # wins in param parsing and would silently discard the picked org.
    it "renders the picker without a competing hidden field for an auditor who is a member" do
      auditor = create(:user, :make_auditor)
      # Unrelated to the combobox; creating a sponsor otherwise calls Stripe.
      allow_any_instance_of(Sponsor).to receive(:create_stripe_customer)
      sponsor = create(:sponsor)
      create(:organizer_position, user: auditor, event: sponsor.event)
      create_session(auditor, verified: true)

      get :edit, params: { id: sponsor.id }

      expect(response).to have_http_status(:ok)
      fields = Nokogiri::HTML(response.body).css("[name='sponsor[event_id]']")
      expect(fields.size).to eq(1)
      expect(fields.first["type"]).to eq("hidden")
      expect(fields.first["id"]).to be_nil

      doc = Nokogiri::HTML(response.body)
      all_ids = doc.css("[id]").map { |el| el["id"] }.tally
      combobox_ids = doc.css("input[role=combobox]").map { |el| el["id"] }
      expect(combobox_ids.map { |id| all_ids[id] }).to all(eq(1))
    end
  end
end
