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
      account_numbers: %w[account_number_type event_id q],
      ach: %w[event_id exclude_reimbursements pending q],
      bank_fees: %w[event_id],
      checks: %w[event_id in_transit q],
      disbursements: %w[event_id pending processing q reviewing],
      donations: %w[deposited event_id failed in_transit ip_address missing_fee_reimbursement missing_payout q user_agent],
      increase_checks: %w[exclude_reimbursements],
      invoices: %w[event_id missing_fee_reimbursement missing_payout number open paid past_due q voided],
      paypal_transfers: %w[event_id q],
      recurring_donations: %w[active canceled event_id],
      reimbursements: %w[event_id failed pending q],
      sponsors: %w[event_id open q],
      stripe_card_personalization_designs: %w[event_id pending q unlisted],
      stripe_cards: %w[q],
      wire_lookup: %w[uetr],
      wires: %w[event_id exclude_reimbursements q],
      wise_transfers: %w[event_id exclude_reimbursements q status],
    }.each do |action, expected|
      it "##{action}" do
        get action

        expect(response).to have_http_status(:ok)
        path = "/admin/#{action}"
        expect(form_fields("get", path)).to eq(expected.sort)
      end
    end

    it "no longer leaks `controller`/`action` into filter URLs" do
      get :ach

      fields = filter_form(ach_admin_index_path).css("input:not([disabled])").map { |i| i["name"] }
      expect(fields).not_to include("controller", "action")
    end

    it "keeps the picker's carried-over params out of the filter form's own submission" do
      get :ach, params: { q: "venue", pending: "1" }

      carried = page.css("[data-controller=menu]:has([data-controller=date-range-picker]) input[type=hidden]")
      expect(carried.map { |i| i["name"] }).to include("q", "pending")
      # Disabled, so they don't submit alongside (and clobber) the real fields.
      expect(carried).to all(satisfy { |i| i["disabled"].present? })
      expect(carried.map { |i| i["name"] }).not_to include("page", "controller", "action", "start_date", "end_date")
    end

    it "the date-range picker still filters the CSV-able pages by date" do
      %i[ach checks disbursements wires wise_transfers].each do |action|
        get action
        expect(page.at_css("[data-controller=date-range-picker]")).to be_present, "#{action} lost its date filter"
      end
    end
  end

  describe "creation forms submit the same params as before" do
    it "card design upload is still multipart with the same params" do
      get :stripe_card_personalization_design_new

      form = page.css("form").find { |f| f["action"] == stripe_card_personalization_design_create_admin_index_path }
      expect(form["enctype"]).to eq("multipart/form-data")
      expect(form_fields("post", stripe_card_personalization_design_create_admin_index_path)).to eq(%w[color logo name])
    end
  end
end
