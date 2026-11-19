# frozen_string_literal: true

require "rails_helper"

# See spec/support/admin_ui_parity_helpers.rb.
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

  end
end
