# frozen_string_literal: true

require "rails_helper"

# See spec/support/admin_ui_parity_helpers.rb.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  include AdminUiParityHelpers
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  describe "the layout" do
    it "still links to Flipper and Blazer, which left the nav model" do
      get :events

      hrefs = page.css("a").map { |a| a["href"] }
      expect(hrefs).to include(flipper_path, blazer_path)
    end

    it "loads the nav for the current page title, as before" do
      get :events

      frame = page.at_css("turbo-frame#admin_nav")
      expect(frame["src"]).to eq(nav_admin_index_path(title: "Organizations"))
      expect(frame["target"]).to eq("_top")
    end
  end
end

RSpec.describe Admin::Nav do
  # Every destination the old sidebar linked to. Blazer and Flipper moved to the
  # layout's "Resources" section (covered above).
  let(:previous_destinations) do
    %w[
      /admin/account_numbers /admin/ach /admin/active_teenagers_leaderboard /admin/applications
      /admin/balances /admin/bank_accounts /admin/bank_fees /admin/check_deposits /admin/column_statements
      /admin/contracts /admin/disbursements /admin/donations /admin/emails /admin/event_groups /admin/events
      /admin/fee_revenues /admin/google_workspaces /admin/hcb_codes /admin/increase_checks /admin/invoices
      /admin/ledger /admin/ledger_audits /admin/ledger_items /admin/legal_entities
      /admin/new_teenagers_leaderboard /admin/payments /admin/payroll_positions /admin/pending_ledger
      /admin/raw_intrafi_transactions /admin/raw_transactions /admin/recurring_donations
      /admin/referral_programs /admin/reimbursements /admin/sponsors
      /admin/stripe_card_personalization_designs /admin/stripe_cards /admin/tax1099_imports/new
      /admin/tax_forms /admin/unknown_merchants /admin/users /admin/wire_lookup /admin/wires
      /admin/wise_transfers /documents /organizer_position_deletion_requests
    ]
  end

  it "still reaches every page the old nav did" do
    paths = described_class.new(page_title: nil).sections.flat_map(&:items).reject(&:divider?).map(&:path)

    expect(paths).to include(*previous_destinations)
  end

  it "doesn't list a page twice" do
    paths = described_class.new(page_title: nil).sections.flat_map(&:items).reject(&:divider?).map(&:path)

    expect(paths).to eq(paths.uniq)
  end

  it "keeps the task counts the old nav showed (except Wire Lookup's hard-coded 0)" do
    nav = described_class.new(page_title: nil)
    counted = nav.sections.flat_map(&:items).select(&:task_count?).map(&:name)

    expect(counted).not_to include("Wire Lookup")
    expect(counted).to include("ACH Transfers", "Wires", "Checks")
  end

  it "highlights leaderboards by their full page title" do
    %w[Active New].each do |kind|
      nav = described_class.new(page_title: "#{kind} Teenagers Leaderboard")

      expect(nav.active_section&.name).to eq("Leaderboards")
      expect(nav.sections.flat_map(&:items).select(&:active?).map(&:name)).to eq(["#{kind} Teenagers"])
    end
  end

  it "points each section at its first real item" do
    described_class.new(page_title: nil).sections.each do |section|
      expect(section.path).to eq(section.items.reject(&:divider?).first.path)
    end
  end
end
