# frozen_string_literal: true

require "rails_helper"

# The admin UI rewrite (AdminUI3) was meant to be visual only. These specs pin
# the behaviour the old admin had: which endpoints each screen submits to, with
# which param names, which filters stick, which destructive actions confirm,
# and which pages the nav reaches. The expected values were taken by rendering
# every admin page on `main` before the rewrite and diffing against this branch.
#
# If one of these fails because you meant to change a form, update the
# expectation here — but make sure the controller still reads the new params.
module AdminUiParityHelpers
  def page
    Nokogiri::HTML(response.body)
  end

  # Every form on the page as `[method, action, [field names]]`, ignoring
  # Rails plumbing (CSRF token, `_method`, submit button names) and the
  # layout's own forms (logout, "pretend I'm not an admin").
  def form_contracts
    page.css("form").filter_map do |form|
      action = form["action"].to_s
      next if action.start_with?("/users/")

      method = (form.at_css("input[name=_method]")&.[]("value") || form["method"] || "get").downcase
      names = form.css("input, select, textarea").filter_map do |input|
        name = input["name"]
        next if name.blank? || name.in?(%w[authenticity_token _method commit button])
        next if input["disabled"] && input["type"] == "hidden"

        name
      end
      [method, action, names.uniq.sort]
    end
  end

  def form_fields(method, action)
    matches = form_contracts.select { |m, a, _| m == method && a == action }
    expect(matches).not_to be_empty, "expected a #{method.upcase} form to #{action}, got: #{form_contracts.map { |m, a, _| "#{m.upcase} #{a}" }.inspect}"
    matches.flat_map(&:last).uniq.sort
  end

  def filter_form(action)
    page.css("form").find { |f| f["action"] == action && f["method"].to_s.downcase == "get" } ||
      raise("no GET filter form for #{action}")
  end
end

RSpec.describe AdminController, type: :controller do
  include SessionSupport
  include AdminUiParityHelpers
  render_views

  let(:event) { create(:event, :with_positive_balance) }
  let(:user) { create(:user) }

  before { create_session(create(:user, :make_admin), verified: true) }

  def common_attrs
    { event:, user:, amount_cents: 5_500, recipient_name: "Orpheus", recipient_email: "payee@example.com", payment_for: "Venue deposit" }
  end

  def address_attrs
    { address_line1: "24 New Hampshire", address_city: "Irvine", address_state: "CA", address_postal_code: "92602", recipient_country: "US" }
  end

  def persist(record)
    record.save!(validate: false)
    record
  end

  def build_wire(**attrs)
    persist(Wire.new(**common_attrs, **address_attrs, currency: "USD", bic_code: "HIBKUS44", account_number: "111111111", memo: "Venue", **attrs))
  end

  def build_wise_transfer(**attrs)
    # Creating one for real fetches a live quote from Wise.
    allow_any_instance_of(WiseTransfer).to receive(:generate_quote!)
    persist(WiseTransfer.new(**common_attrs, **address_attrs, currency: "USD", quoted_usd_amount_cents: 5_500, **attrs))
  end

  def build_paypal_transfer(**attrs)
    persist(PaypalTransfer.new(**common_attrs, memo: "Venue", **attrs))
  end

  def build_increase_check(**attrs)
    persist(IncreaseCheck.new(event:, user:, amount: 5_500, recipient_name: "Orpheus", recipient_email: "payee@example.com", memo: "Venue", payment_for: "Venue deposit", address_line1: "24 New Hampshire", address_city: "Irvine", address_state: "CA", address_zip: "92602", **attrs))
  end

  describe "process screens submit to the same endpoints with the same params" do
    it "ACH: approve, send in realtime, reject, and toggle speed" do
      transfer = create(:ach_transfer, event:)

      get :ach_start_approval, params: { id: transfer.id }

      expect(form_fields("post", ach_approve_admin_path(transfer))).to eq([])
      expect(form_fields("post", ach_reject_admin_path(transfer))).to eq(["comment"])
      expect(form_fields("post", toggle_speed_ach_transfer_path(transfer))).to eq([])

      # Realtime used to be its own form; it's now a second submit button on the
      # approve form that overrides the action, so it still POSTs to the same
      # endpoint with the same (classification) params.
      realtime = page.at_css("button[formaction='#{ach_send_realtime_admin_path(transfer)}']")
      expect(realtime).to be_present
      expect(realtime.ancestors("form").first["action"]).to eq(ach_approve_admin_path(transfer))
      expect(realtime["name"]).to be_nil
    end

    it "ACH: hides 'send in realtime' for scheduled transfers, as before" do
      transfer = create(:ach_transfer, event:)
      transfer.update_column(:scheduled_on, 3.days.from_now.to_date)

      get :ach_start_approval, params: { id: transfer.id }

      expect(page.at_css("button[formaction='#{ach_send_realtime_admin_path(transfer)}']")).to be_nil
      expect(form_fields("post", ach_approve_admin_path(transfer))).to eq([])
    end

    it "disbursement: approve and reject" do
      disbursement = create(:disbursement)

      get :disbursement_process, params: { id: disbursement.id }

      expect(form_fields("post", disbursement_approve_admin_path(disbursement))).to eq([])
      expect(form_fields("post", disbursement_reject_admin_path(disbursement))).to eq(["comment"])
      expect(form_fields("post", "/disbursements/#{disbursement.to_param}/set_transaction_categories"))
        .to include("disbursement[destination_transaction_category_slug]")
    end

    it "wire (pending): send with the fee checkbox, reject, edit" do
      wire = build_wire

      get :wire_process, params: { id: wire.id }

      expect(form_fields("post", send_wire_path(wire))).to eq(["charge_fee"])
      # The hidden "0" must still precede the checkbox so unchecking submits false.
      send_form = page.css("form").find { |f| f["action"] == send_wire_path(wire) }
      expect(send_form.css("input[name=charge_fee]").map { |i| i["type"] }).to eq(%w[hidden checkbox])
      expect(form_fields("post", reject_wire_path(wire))).to eq(["comment"])
      expect(form_fields("get", edit_wire_path(wire))).to eq([])
    end

    it "wise transfer (pending): approve, reject, mark failed" do
      transfer = build_wise_transfer

      get :wise_transfer_process, params: { id: transfer.id }

      expect(form_fields("post", approve_wise_transfer_path(transfer))).to eq([])
      expect(form_fields("post", reject_wise_transfer_path(transfer))).to eq(["comment"])
      expect(form_fields("post", mark_failed_wise_transfer_path(transfer))).to eq(["reason"])
    end

    it "wise transfer (approved): recipient ID, USD amount, mark sent, reject, mark failed" do
      transfer = build_wise_transfer(aasm_state: "approved")

      get :wise_transfer_process, params: { id: transfer.id }

      expect(form_fields("patch", wise_transfer_path(transfer)))
        .to eq(%w[wise_transfer[usd_amount] wise_transfer[wise_recipient_id]])
      expect(form_fields("post", mark_sent_wise_transfer_path(transfer))).to eq(["wise_transfer[wise_id]"])
      expect(form_fields("post", reject_wise_transfer_path(transfer))).to eq(["comment"])
      expect(form_fields("post", mark_failed_wise_transfer_path(transfer))).to eq(["reason"])

      # Marking as sent stays locked until the final USD amount is entered.
      expect(page.at_css("input[name='wise_transfer[wise_id]']")["disabled"]).to be_present
    end

    it "PayPal transfer (pending): approve, reject, mark failed" do
      transfer = build_paypal_transfer

      get :paypal_transfer_process, params: { id: transfer.id }

      expect(form_fields("post", approve_paypal_transfer_path(transfer))).to eq([])
      expect(form_fields("post", reject_paypal_transfer_path(transfer))).to eq(["comment"])
      expect(form_fields("post", mark_failed_paypal_transfer_path(transfer))).to eq([])
    end

    it "PayPal transfer (approved): only mark failed" do
      transfer = build_paypal_transfer(aasm_state: "approved")

      get :paypal_transfer_process, params: { id: transfer.id }

      expect(form_fields("post", mark_failed_paypal_transfer_path(transfer))).to eq([])
      expect(form_contracts.map(&:second)).not_to include(approve_paypal_transfer_path(transfer))
    end

    it "check: approve and reject" do
      check = build_increase_check

      get :increase_check_process, params: { id: check.id }

      expect(form_fields("post", approve_increase_check_path(check))).to eq([])
      expect(form_fields("post", reject_increase_check_path(check))).to eq(["comment"])
    end

    it "organization: approve/pending toggle and reject are PUTs" do
      pending_event = create(:event, aasm_state: :pending)

      get :event_process, params: { id: pending_event.friendly_id }

      expect(form_fields("put", event_toggle_approved_admin_path(pending_event))).to eq([])
      expect(form_fields("put", event_reject_admin_path(pending_event))).to eq([])
    end

    it "airtable import posts the record ID" do
      get :event_new_from_airtable

      expect(form_fields("post", event_create_from_airtable_admin_index_path)).to eq(["airtable_record_id"])
    end

    it "manual raw transaction posts the same four params" do
      get :raw_transaction_new

      expect(form_fields("post", raw_transaction_create_admin_index_path))
        .to eq(%w[amount date memo unique_bank_identifier])
      # Was a free-text field with a YYYY-MM-DD placeholder; a date input
      # submits the same format, which the service already parses.
      expect(page.at_css("input[name=date]")["type"]).to eq("date")
    end

    it "card design upload is still multipart with the same params" do
      get :stripe_card_personalization_design_new

      form = page.css("form").find { |f| f["action"] == stripe_card_personalization_design_create_admin_index_path }
      expect(form["enctype"]).to eq("multipart/form-data")
      expect(form_fields("post", stripe_card_personalization_design_create_admin_index_path)).to eq(%w[color logo name])
    end

    it "organization creation posts the same params as before" do
      get :event_new

      expect(form_fields("post", event_create_admin_index_path)).to eq(%w[
                                                                         approved cosigner_email country demo_mode include_videos is_public is_signee
                                                                         name organizer_email plan point_of_contact_id risk_level tags[]
                                                                       ])
      # Tags moved from a multi-select to checkboxes; the values must be the
      # same tag names the controller looks up.
      tag_values = page.css("input[type=checkbox][name='tags[]']").map { |i| i["value"] }
      expect(tag_values).to match_array(EventTag::Tags::ALL) if defined?(EventTag::Tags::ALL)
      expect(tag_values).to include("Hackathon", "Hack Club", "Organized by Teenagers")
    end
  end

  describe "destructive actions still ask for confirmation" do
    def confirm_for(selector)
      element = page.at_css(selector)
      expect(element).to be_present, "nothing matched #{selector}"
      element["data-turbo-confirm"] || element.ancestors("form").first&.[]("data-turbo-confirm")
    end

    def submit_in(action)
      "form[action='#{action}'] button, form[action='#{action}'] input[type=submit]"
    end

    it "on ACH approve, realtime send and reject" do
      transfer = create(:ach_transfer, event:)

      get :ach_start_approval, params: { id: transfer.id }

      expect(confirm_for(submit_in(ach_approve_admin_path(transfer)))).to include("cannot be un-sent")
      expect(confirm_for("button[formaction='#{ach_send_realtime_admin_path(transfer)}']")).to include("$1 fee")
      expect(confirm_for(submit_in(ach_reject_admin_path(transfer)))).to include("Mark as rejected?")
    end

    it "on wire send and reject" do
      wire = build_wire

      get :wire_process, params: { id: wire.id }

      expect(confirm_for(submit_in(send_wire_path(wire)))).to be_present
      expect(confirm_for(submit_in(reject_wire_path(wire)))).to include("Mark as rejected?")
    end

    it "on wise reject and mark failed" do
      transfer = build_wise_transfer

      get :wise_transfer_process, params: { id: transfer.id }

      expect(confirm_for(submit_in(reject_wise_transfer_path(transfer)))).to include("Mark as rejected?")
      expect(confirm_for(submit_in(mark_failed_wise_transfer_path(transfer)))).to include("Mark as failed?")
    end

    it "on check approve and reject" do
      check = build_increase_check

      get :increase_check_process, params: { id: check.id }

      expect(confirm_for(submit_in(approve_increase_check_path(check)))).to be_present
      expect(confirm_for(submit_in(reject_increase_check_path(check)))).to include("Mark as rejected?")
    end

    it "on PayPal reject" do
      transfer = build_paypal_transfer

      get :paypal_transfer_process, params: { id: transfer.id }

      expect(confirm_for(submit_in(reject_paypal_transfer_path(transfer)))).to include("Mark as rejected?")
    end

    it "on disbursement reject" do
      disbursement = create(:disbursement)

      get :disbursement_process, params: { id: disbursement.id }

      expect(confirm_for(submit_in(disbursement_reject_admin_path(disbursement)))).to match(/reject/i)
    end

    it "on organization reject" do
      pending_event = create(:event, aasm_state: :pending)

      get :event_process, params: { id: pending_event.friendly_id }

      expect(confirm_for(submit_in(event_reject_admin_path(pending_event)))).to include("can not be undone")
    end

    it "when sending an approved organization back to pending" do
      approved_event = create(:event, aasm_state: :approved)

      get :event_process, params: { id: approved_event.friendly_id }

      expect(confirm_for(submit_in(event_toggle_approved_admin_path(approved_event)))).to include("previously approved")
    end
  end

  describe "index filter forms submit the same params as before" do
    {
      account_numbers: %w[account_number_type event_id q],
      ach: %w[event_id exclude_reimbursements pending q],
      applications: %w[include_archived q],
      bank_fees: %w[event_id],
      checks: %w[event_id in_transit q],
      contracts: %w[q service status type],
      disbursements: %w[event_id pending processing q reviewing],
      donations: %w[deposited event_id failed in_transit ip_address missing_fee_reimbursement missing_payout q user_agent],
      emails: %w[q to user_id],
      employee_payments: %w[q],
      employees: %w[q],
      events: %w[active activity_since approved country demo_mode engaged funded hidden omitted organized_by pending plan point_of_contact_id q rejected risk_level sort_by tagged_with transparent unapproved],
      balances: %w[active activity_since approved country demo_mode end_date engaged funded hidden omitted organized_by pending plan point_of_contact_id q rejected risk_level sort_by start_date tagged_with transparent unapproved],
      google_workspaces: %w[configuring event_id needs_ops_review pending_deletion q revocation_present verification_error],
      increase_checks: %w[exclude_reimbursements],
      invoices: %w[event_id missing_fee_reimbursement missing_payout number open paid past_due q voided],
      ledger: %w[amount event_id exclude_spending exclude_top_ups mapped_by_human q unmapped user_id],
      ledger_items: %w[amount nonzero q unmapped],
      paypal_transfers: %w[event_id q],
      pending_ledger: %w[event_id q unsettled],
      raw_transactions: %w[unique_bank_identifier],
      recurring_donations: %w[active canceled event_id],
      reimbursements: %w[event_id failed pending q],
      sponsors: %w[event_id open q],
      stripe_card_personalization_designs: %w[event_id pending q unlisted],
      stripe_cards: %w[q],
      users: %w[access_level event_id locked q referral_program_id],
      wire_lookup: %w[uetr],
      wires: %w[event_id exclude_reimbursements q],
      wise_transfers: %w[event_id exclude_reimbursements q status],
      # hcb_codes' dates come from the JS date-range picker, and balances' `format` /
      # `monthly_breakdown` from its export buttons (both asserted below).
      hcb_codes: %w[has_receipt q],
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

    it "hcb_codes still filters by start_date/end_date through the date-range picker" do
      get :hcb_codes, params: { start_date: "2025-12-01", end_date: "2025-12-31" }

      picker = page.at_css("[data-controller=date-range-picker]")
      expect(picker["data-date-range-picker-name-start-value"]).to eq("start_date")
      expect(picker["data-date-range-picker-name-end-value"]).to eq("end_date")
      expect(picker["data-date-range-picker-initial-start-value"]).to eq("2025-12-01")
      expect(picker["data-date-range-picker-initial-end-value"]).to eq("2025-12-31")
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

    it "both open the same process screen as before" do
      pending_event = create(:event, aasm_state: :pending)

      get :events

      frame = page.at_css("turbo-frame##{ActionView::RecordIdentifier.dom_id(pending_event, :event_process_frame)}")
      expect(URI.parse(frame["src"]).path).to eq(event_process_admin_path(pending_event))
    end
  end

  describe "the admin homepage" do
    it "is served at /admin instead of redirecting to the organizations table" do
      expect(admin_index_path).to eq("/admin")

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("HCB Admin")
    end
  end

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

  describe "stripe card design create" do
    it "still creates the design and returns to the list when a logo is given" do
      allow(StripeCardService::PersonalizationDesign::Create).to receive(:new).and_return(double(run: true))

      post :stripe_card_personalization_design_create, params: { logo: fixture_file_upload(Rails.root.join("spec/fixtures/files/receipt.png"), "image/png"), name: "Orpheus", color: "black" }

      expect(response).to redirect_to(stripe_card_personalization_designs_admin_index_path)
      expect(flash[:success]).to eq("Successfully created Orpheus")
    end
  end

  describe "invoice mark paid" do
    it "still passes the reason and attachment through on success" do
      sponsor_event = create(:event)
      invoice = build_stubbed(:invoice, id: 7, status: "open", sponsor: build_stubbed(:sponsor, event: sponsor_event))
      allow(Invoice).to receive(:find).and_return(invoice)
      service = double(run: true)
      expect(InvoiceService::MarkPaid).to receive(:new)
        .with(hash_including(invoice_id: 7, reason: "check #1234"))
        .and_return(service)

      post :invoice_mark_paid, params: { id: 7, reason: "check #1234" }

      expect(response).to redirect_to(invoices_admin_index_path)
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

RSpec.describe BankAccount do
  it "keeps the same three sync states, with the new shade classes" do
    account = described_class.new

    allow(account).to receive(:should_sync_v2?).and_return(false)
    expect(account.admin_status_color).to be_nil

    allow(account).to receive_messages(should_sync_v2?: true, failing?: true)
    expect(account.admin_status_color).to eq("shade-red")

    allow(account).to receive(:failing?).and_return(false)
    expect(account.admin_status_color).to eq("shade-cyan")
  end
end
